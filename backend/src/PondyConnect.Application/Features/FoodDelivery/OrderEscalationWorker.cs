namespace PondyConnect.Application.Features.FoodDelivery;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background worker that monitors food orders in the <see cref="FoodOrderStatus.Placed"/>
/// (unacknowledged) state. If a merchant hasn't acknowledged a new order within
/// 3 minutes — typically because their WiFi dropped or the tablet is asleep —
/// the worker triggers an automated SMS/IVR fallback to the restaurant
/// manager's registered phone number:
///
/// <example>
/// "Hello {Restaurant}. You have a new PY Connect order waiting.
/// Please check your tablet immediately."
/// </example>
///
/// This prevents the scenario where a driver arrives for food that was
/// never cooked because the merchant never saw the order.
/// </summary>
public sealed class OrderEscalationWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<OrderEscalationWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromMinutes(1);

    /// <summary>
    /// How long an order can remain unacknowledged before the IVR/SMS
    /// fallback is triggered. 3 minutes gives the merchant enough time
    /// to hear the KDS chime and tap "Accept", but catches WiFi drops
    /// before the driver arrives for uncooked food.
    /// </summary>
    private static readonly TimeSpan EscalationThreshold = TimeSpan.FromMinutes(3);

    /// <summary>
    /// Orders that have already been escalated. Prevents duplicate SMS
    /// on every worker cycle.
    /// </summary>
    private readonly HashSet<Guid> _escalatedOrders = new();

    public OrderEscalationWorker(IServiceProvider serviceProvider, ILogger<OrderEscalationWorker> logger)
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
                var smsSender = scope.ServiceProvider.GetService<ISmsSender>();

                await MonitorUnacknowledgedOrdersAsync(context, smsSender, stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.OrderEscalationWorkerError(ex);
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task MonitorUnacknowledgedOrdersAsync(
        IApplicationDbContext context,
        ISmsSender? smsSender,
        CancellationToken cancellationToken)
    {
        var cutoff = DateTimeOffset.UtcNow.Subtract(EscalationThreshold);

        // Find all food orders still in the Placed state that were placed
        // more than 3 minutes ago.
        var unacknowledgedOrders = await context.FoodOrders
            .Where(o => o.Status == FoodOrderStatus.Placed && o.PlacedAt < cutoff)
            .ToListAsync(cancellationToken);

        if (unacknowledgedOrders.Count == 0) return;

        _logger.OrderEscalationStarted(unacknowledgedOrders.Count);

        // Collect unique vendor IDs to batch-fetch contact info.
        var vendorIds = unacknowledgedOrders.Select(o => o.VendorId).Distinct().ToList();
        var vendors = await context.Vendors
            .Where(v => vendorIds.Contains(v.Id))
            .ToDictionaryAsync(v => v.Id, cancellationToken);

        foreach (var order in unacknowledgedOrders)
        {
            // Skip orders already escalated to prevent duplicate SMS.
            if (_escalatedOrders.Contains(order.Id))
                continue;

            if (!vendors.TryGetValue(order.VendorId, out var vendor))
                continue;

            if (smsSender is not null && !string.IsNullOrEmpty(vendor.ContactPhone))
            {
                try
                {
                    var message =
                        $"PY Connect: You have a new order (#{order.Id.ToString().Substring(0, 8).ToUpperInvariant()}) " +
                        $"waiting. Please check your tablet immediately.";

                    await smsSender.SendAsync(vendor.ContactPhone, message, cancellationToken);
                    _logger.OrderEscalationSmsSent(order.Id, vendor.Name, vendor.ContactPhone);
                }
                catch (Exception ex)
                {
                    _logger.OrderEscalationSmsFailed(order.Id, ex);
                }
            }
            else
            {
                _logger.OrderEscalationNoPhone(order.Id, vendor.Name);
            }

            _escalatedOrders.Add(order.Id);
        }
    }
}

internal static partial class OrderEscalationLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Order escalation started for {Count} unacknowledged orders")]
    public static partial void OrderEscalationStarted(this ILogger logger, int count);

    [LoggerMessage(Level = LogLevel.Information, Message = "Order escalation SMS sent to {Phone} for {VendorName} (order {OrderId})")]
    public static partial void OrderEscalationSmsSent(this ILogger logger, Guid orderId, string vendorName, string phone);

    [LoggerMessage(Level = LogLevel.Error, Message = "Failed to send order escalation SMS for order {OrderId}")]
    public static partial void OrderEscalationSmsFailed(this ILogger logger, Guid orderId, Exception ex);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Order {OrderId} for {VendorName} has no contact phone — cannot escalate")]
    public static partial void OrderEscalationNoPhone(this ILogger logger, Guid orderId, string vendorName);

    [LoggerMessage(Level = LogLevel.Error, Message = "Order escalation worker error")]
    public static partial void OrderEscalationWorkerError(this ILogger logger, Exception ex);
}
