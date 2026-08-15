namespace PondyConnect.Application.Features.Payments;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background worker that runs every 3 minutes to reconcile payments
/// where the user paid via UPI but the app lost network before confirming.
///
/// For each payment that is still <see cref="PaymentStatus.Unpaid"/> and was
/// created more than 5 minutes ago, the worker calls the Razorpay API to
/// check the actual status of the provider order:
/// <list type="bullet">
///   <item>If paid at Razorpay → transition to Captured, confirm the booking,
///   and dispatch to the merchant/driver via the booking engine.</item>
///   <item>If failed or still pending after 30 minutes → transition to
///   Failed, cancel the booking, and release any locked inventory/capacity.</item>
/// </list>
///
/// This worker is idempotent: <see cref="BookingEngineService.ReconcilePaymentAsync"/>
/// bails early when the payment is already captured, so concurrent webhook
/// arrivals and worker runs are safe.
/// </summary>
public sealed class PaymentReconciliationWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<PaymentReconciliationWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromMinutes(3);
    private static readonly TimeSpan PendingThreshold = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan FailureThreshold = TimeSpan.FromMinutes(30);

    public PaymentReconciliationWorker(IServiceProvider serviceProvider, ILogger<PaymentReconciliationWorker> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                var gateway = scope.ServiceProvider.GetRequiredService<IPaymentGateway>();
                var engine = scope.ServiceProvider.GetRequiredService<IBookingEngineService>();

                await ReconcilePendingPaymentsAsync(context, gateway, engine, stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.PaymentReconciliationWorkerError(ex);
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task ReconcilePendingPaymentsAsync(
        IApplicationDbContext context,
        IPaymentGateway gateway,
        IBookingEngineService engine,
        CancellationToken cancellationToken)
    {
        var cutoff = DateTimeOffset.UtcNow.Subtract(PendingThreshold);
        var failureCutoff = DateTimeOffset.UtcNow.Subtract(FailureThreshold);

        // Find all unpaid payments with a provider order ID that are older
        // than 5 minutes. These are candidates for reconciliation — the user
        // may have paid at Razorpay but the app never got the confirmation.
        var pendingPayments = await context.Payments
            .Where(p => p.Status == PaymentStatus.Unpaid
                && p.ProviderOrderId != null
                && p.CreatedAt < cutoff)
            .ToListAsync(cancellationToken);

        if (pendingPayments.Count == 0)
            return;

        _logger.PaymentReconciliationStarted(pendingPayments.Count);

        foreach (var payment in pendingPayments)
        {
            try
            {
                var providerStatus = await gateway.FetchOrderStatusAsync(payment.ProviderOrderId!, cancellationToken);
                if (!providerStatus.Success)
                {
                    _logger.PaymentReconciliationFetchFailed(payment.Id, providerStatus.ErrorMessage ?? "Unknown error");
                    continue;
                }

                if (providerStatus.Status == PaymentStatus.Captured && providerStatus.ProviderPaymentId is not null)
                {
                    // Paid at Razorpay → reconcile through the booking engine,
                    // which confirms the booking and dispatches to merchant/driver.
                    var result = await engine.ReconcilePaymentAsync(
                        new ReconcilePaymentRequest(
                            providerStatus.ProviderOrderId!,
                            providerStatus.ProviderPaymentId),
                        cancellationToken);

                    _logger.PaymentReconciled(payment.Id, result.AlreadyReconciled ? "already" : "captured");
                }
                else if (providerStatus.Status == PaymentStatus.Failed || payment.CreatedAt < failureCutoff)
                {
                    // Failed at Razorpay or pending beyond the failure threshold
                    // → mark as failed and release any locked inventory/capacity.
                    var reason = providerStatus.Status == PaymentStatus.Failed
                        ? "Payment failed at provider"
                        : "Payment timed out (30 min)";
                    payment.MarkFailed(reason);
                    await context.SaveChangesAsync(cancellationToken);

                    await ReleaseInventoryAsync(context, payment, cancellationToken);

                    _logger.PaymentReconciliationFailed(payment.Id, reason);
                }
            }
            catch (Exception ex)
            {
                _logger.PaymentReconciliationItemError(payment.Id, ex);
            }
        }
    }

    /// <summary>
    /// Releases any locked inventory/capacity for a failed payment. For
    /// service bookings, cancels the booking so the venue capacity is freed.
    /// For food orders, cancels the order. For transit trips, releases the
    /// trip. This prevents a stuck payment from holding inventory forever.
    /// </summary>
    private static async Task ReleaseInventoryAsync(
        IApplicationDbContext context,
        Domain.Entities.Payment payment,
        CancellationToken cancellationToken)
    {
        if (payment.ServiceBookingId is { } bookingId)
        {
            var booking = await context.ServiceBookings
                .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);
            if (booking is not null && booking.Status != Domain.Enums.BookingStatus.Cancelled)
            {
                booking.Cancel();
                await context.SaveChangesAsync(cancellationToken);
            }
        }
        else if (payment.FoodOrderId is { } foodOrderId)
        {
            var order = await context.FoodOrders
                .FirstOrDefaultAsync(f => f.Id == foodOrderId, cancellationToken);
            if (order is not null && order.Status != Domain.Enums.FoodOrderStatus.Cancelled)
            {
                order.Cancel();
                await context.SaveChangesAsync(cancellationToken);
            }
        }
    }
}

internal static partial class PaymentReconciliationLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Payment reconciliation started for {Count} pending payments")]
    public static partial void PaymentReconciliationStarted(this ILogger logger, int count);

    [LoggerMessage(Level = LogLevel.Information, Message = "Payment {PaymentId} reconciled ({Result})")]
    public static partial void PaymentReconciled(this ILogger logger, Guid paymentId, string result);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Payment {PaymentId} reconciliation failed: {Reason}")]
    public static partial void PaymentReconciliationFailed(this ILogger logger, Guid paymentId, string reason);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Failed to fetch status for payment {PaymentId}: {Error}")]
    public static partial void PaymentReconciliationFetchFailed(this ILogger logger, Guid paymentId, string error);

    [LoggerMessage(Level = LogLevel.Error, Message = "Error reconciling payment {PaymentId}")]
    public static partial void PaymentReconciliationItemError(this ILogger logger, Guid paymentId, Exception ex);

    [LoggerMessage(Level = LogLevel.Error, Message = "Error in PaymentReconciliationWorker")]
    public static partial void PaymentReconciliationWorkerError(this ILogger logger, Exception ex);
}
