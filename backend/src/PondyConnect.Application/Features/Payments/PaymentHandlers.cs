namespace PondyConnect.Application.Features.Payments;

using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class InitiatePaymentHandler : IRequestHandler<InitiatePaymentCommand, InitiatePaymentResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IPaymentGateway _gateway;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<InitiatePaymentHandler> _logger;

    public InitiatePaymentHandler(IApplicationDbContext context, IPaymentGateway gateway, ICurrentUserService currentUser, ILogger<InitiatePaymentHandler> logger)
    {
        _context = context;
        _gateway = gateway;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<InitiatePaymentResponse> Handle(InitiatePaymentCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        // Verify ownership of the referenced booking
        if (request.ServiceBookingId.HasValue)
        {
            var exists = await _context.ServiceBookings
                .AnyAsync(b => b.Id == request.ServiceBookingId.Value && b.UserId == userId, cancellationToken);
            if (!exists) throw new InvalidOperationException("Service booking not found or access denied.");
        }
        else if (request.TransitTripId.HasValue)
        {
            var exists = await _context.TransitTrips
                .AnyAsync(t => t.Id == request.TransitTripId.Value && t.UserId == userId, cancellationToken);
            if (!exists) throw new InvalidOperationException("Transit trip not found or access denied.");
        }
        else if (request.LuggageDropOffId.HasValue)
        {
            var exists = await _context.LuggageDropOffs
                .AnyAsync(l => l.Id == request.LuggageDropOffId.Value && l.UserId == userId, cancellationToken);
            if (!exists) throw new InvalidOperationException("Luggage drop-off not found or access denied.");
        }
        else if (request.ScooterRentalId.HasValue)
        {
            var exists = await _context.ScooterRentals
                .AnyAsync(r => r.Id == request.ScooterRentalId.Value && r.UserId == userId, cancellationToken);
            if (!exists) throw new InvalidOperationException("Scooter rental not found or access denied.");
        }
        else if (request.FoodOrderId.HasValue)
        {
            var exists = await _context.FoodOrders
                .AnyAsync(f => f.Id == request.FoodOrderId.Value && f.UserId == userId, cancellationToken);
            if (!exists) throw new InvalidOperationException("Food order not found or access denied.");
        }

        // Idempotency: return the existing unpaid payment for the same booking
        // instead of creating a duplicate. This prevents double-charges from retry logic.
        Payment? existingPayment = null;
        if (request.ServiceBookingId.HasValue)
            existingPayment = await _context.Payments.FirstOrDefaultAsync(p =>
                p.ServiceBookingId == request.ServiceBookingId.Value &&
                p.Status == PaymentStatus.Unpaid && p.ProviderOrderId != null,
                cancellationToken);
        else if (request.TransitTripId.HasValue)
            existingPayment = await _context.Payments.FirstOrDefaultAsync(p =>
                p.TransitTripId == request.TransitTripId.Value &&
                p.Status == PaymentStatus.Unpaid && p.ProviderOrderId != null,
                cancellationToken);
        else if (request.LuggageDropOffId.HasValue)
            existingPayment = await _context.Payments.FirstOrDefaultAsync(p =>
                p.LuggageDropOffId == request.LuggageDropOffId.Value &&
                p.Status == PaymentStatus.Unpaid && p.ProviderOrderId != null,
                cancellationToken);
        else if (request.ScooterRentalId.HasValue)
            existingPayment = await _context.Payments.FirstOrDefaultAsync(p =>
                p.ScooterRentalId == request.ScooterRentalId.Value &&
                p.Status == PaymentStatus.Unpaid && p.ProviderOrderId != null,
                cancellationToken);
        else if (request.FoodOrderId.HasValue)
            existingPayment = await _context.Payments.FirstOrDefaultAsync(p =>
                p.FoodOrderId == request.FoodOrderId.Value &&
                p.Status == PaymentStatus.Unpaid && p.ProviderOrderId != null,
                cancellationToken);

        if (existingPayment is not null && existingPayment.ProviderOrderId is not null)
            return new InitiatePaymentResponse(existingPayment.Id, existingPayment.ProviderOrderId, null);

        // Create payment record
        Payment payment;
        var receiptId = $"{userId:N}-{Guid.NewGuid():N}".Substring(0, 40);
        if (request.ServiceBookingId.HasValue)
            payment = Payment.CreateForServiceBooking(request.ServiceBookingId.Value, request.Amount, request.Provider, request.Method);
        else if (request.TransitTripId.HasValue)
            payment = Payment.CreateForTransitTrip(request.TransitTripId.Value, request.Amount, request.Provider, request.Method);
        else if (request.LuggageDropOffId.HasValue)
            payment = Payment.CreateForLuggageDropOff(request.LuggageDropOffId.Value, request.Amount, request.Provider, request.Method);
        else if (request.ScooterRentalId.HasValue)
            payment = Payment.CreateForScooterRental(request.ScooterRentalId.Value, request.Amount, request.Provider, request.Method);
        else
            payment = Payment.CreateForFoodOrder(request.FoodOrderId!.Value, request.Amount, request.Provider, request.Method);

        _context.Payments.Add(payment);
        await _context.SaveChangesAsync(cancellationToken);

        // Create order with provider
        var orderResult = await _gateway.CreateOrderAsync(request.Amount, request.Currency, receiptId, cancellationToken: cancellationToken);
        if (!orderResult.Success)
        {
            _logger.LogError("Payment order creation failed for user {UserId}: {Error}", userId, orderResult.ErrorMessage);
            throw new InvalidOperationException($"Payment order creation failed: {orderResult.ErrorMessage}");
        }

        payment.MarkProviderOrderCreated(orderResult.OrderId!);
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} initiated for user {UserId}, amount {Amount}", payment.Id, userId, request.Amount);

        return new InitiatePaymentResponse(payment.Id, orderResult.OrderId!, orderResult.ShortUrl);
    }
}

public sealed class VerifyPaymentWebhookHandler : IRequestHandler<VerifyPaymentWebhookCommand, VerifyPaymentWebhookResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IPaymentGateway _gateway;
    private readonly IBookingEngineService _engine;

    public VerifyPaymentWebhookHandler(
        IApplicationDbContext context,
        IPaymentGateway gateway,
        IBookingEngineService engine)
    {
        _context = context;
        _gateway = gateway;
        _engine = engine;
    }

    public async Task<VerifyPaymentWebhookResponse> Handle(VerifyPaymentWebhookCommand request, CancellationToken cancellationToken)
    {
        var result = await _gateway.VerifyWebhookAsync(request.Payload, request.Signature, cancellationToken);
        if (!result.IsValid)
            return new VerifyPaymentWebhookResponse(false);

        // ── Idempotency: if this Razorpay event has already been processed,
        // short-circuit to 200 OK without re-charging or double-confirming.
        // Razorpay redelivers webhooks on timeout, so this guard is critical
        // for financial safety.
        var eventId = result.EventId;
        if (!string.IsNullOrWhiteSpace(eventId))
        {
            var alreadyProcessed = await _context.ProcessedWebhooks
                .AsNoTracking()
                .AnyAsync(w => w.EventId == eventId, cancellationToken);

            if (alreadyProcessed)
                return new VerifyPaymentWebhookResponse(true, eventId, PaymentStatus.Captured);
        }

        if (result.Status == PaymentStatus.Captured)
        {
            // Process the payment and record the event idempotency within a
            // single atomic transaction. If the reconciliation succeeds but
            // the ProcessedWebhook insert fails, the whole transaction rolls
            // back — so a retry will re-reconcile (which is itself idempotent)
            // and then record the event.
            await using var transaction = await _context.BeginTransactionAsync(cancellationToken);
            try
            {
                var reconciled = await _engine.ReconcilePaymentAsync(
                    new ReconcilePaymentRequest(
                        result.ProviderOrderId!,
                        result.ProviderPaymentId!),
                    cancellationToken);

                if (!string.IsNullOrWhiteSpace(eventId))
                {
                    _context.ProcessedWebhooks.Add(ProcessedWebhook.Create(
                        eventId,
                        result.EventType ?? "payment.captured",
                        request.Payload));
                    await _context.SaveChangesAsync(cancellationToken);
                }

                if (transaction is not null)
                    await transaction.CommitAsync(cancellationToken);

                return new VerifyPaymentWebhookResponse(true, reconciled.PaymentId.ToString(), PaymentStatus.Captured);
            }
            catch
            {
                if (transaction is not null)
                    await transaction.RollbackAsync(cancellationToken);
                throw;
            }
        }

        // Non-captured result: record the failed payment idempotently.
        // Skip if the payment is already captured (webhook replay after success)
        // or already failed (duplicate webhook delivery).
        var payment = await _context.Payments
            .FirstOrDefaultAsync(p => p.ProviderOrderId == result.ProviderOrderId, cancellationToken);
        if (payment is not null && payment.Status == PaymentStatus.Unpaid)
        {
            payment.MarkFailed(result.ErrorMessage ?? "Payment failed");
            await _context.SaveChangesAsync(cancellationToken);
        }

        // Record the event even for failed payments so a redelivery is a no-op.
        if (!string.IsNullOrWhiteSpace(eventId))
        {
            _context.ProcessedWebhooks.Add(ProcessedWebhook.Create(
                eventId,
                result.EventType ?? "payment.failed",
                request.Payload));
            await _context.SaveChangesAsync(cancellationToken);
        }

        return new VerifyPaymentWebhookResponse(false);
    }
}

public sealed class VerifyPaymentHandler : IRequestHandler<VerifyPaymentCommand, VerifyPaymentResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IPaymentGateway _gateway;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<VerifyPaymentHandler> _logger;

    public VerifyPaymentHandler(
        IApplicationDbContext context,
        IPaymentGateway gateway,
        ICurrentUserService currentUser,
        ILogger<VerifyPaymentHandler> logger)
    {
        _context = context;
        _gateway = gateway;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<VerifyPaymentResponse> Handle(VerifyPaymentCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var payment = await _context.Payments
            .FirstOrDefaultAsync(p => p.Id == request.PaymentId, cancellationToken);
        if (payment is null)
            throw new InvalidOperationException("Payment not found.");

        // Verify ownership of the underlying booking so a user cannot verify
        // (and capture) another user's payment.
        var owns = payment.ServiceBookingId.HasValue
            ? await _context.ServiceBookings.AnyAsync(b => b.Id == payment.ServiceBookingId.Value && b.UserId == userId, cancellationToken)
            : payment.TransitTripId.HasValue
                ? await _context.TransitTrips.AnyAsync(t => t.Id == payment.TransitTripId.Value && t.UserId == userId, cancellationToken)
                : payment.LuggageDropOffId.HasValue
                    ? await _context.LuggageDropOffs.AnyAsync(l => l.Id == payment.LuggageDropOffId.Value && l.UserId == userId, cancellationToken)
                    : payment.ScooterRentalId.HasValue
                        ? await _context.ScooterRentals.AnyAsync(r => r.Id == payment.ScooterRentalId.Value && r.UserId == userId, cancellationToken)
                        : payment.FoodOrderId.HasValue
                            ? await _context.FoodOrders.AnyAsync(f => f.Id == payment.FoodOrderId.Value && f.UserId == userId, cancellationToken)
                            : false;

        if (!owns)
            throw new UnauthorizedAccessException("Access denied to this payment.");

        // Razorpay client-side signature is HMAC-SHA256 of "order_id|payment_id"
        // keyed by the provider key secret.
        var isValid = await _gateway.VerifyPaymentSignatureAsync(
            request.RazorpayOrderId,
            request.RazorpayPaymentId,
            request.RazorpaySignature,
            cancellationToken);

        if (!isValid)
        {
            _logger.LogWarning("Payment signature verification failed for payment {PaymentId}", request.PaymentId);
            return new VerifyPaymentResponse(false, "Invalid signature");
        }

        // Signature valid: mark the payment as captured.
        payment.MarkCaptured(request.RazorpayPaymentId);
        await _context.SaveChangesAsync(cancellationToken);

        _logger.LogInformation("Payment {PaymentId} verified and captured for user {UserId}", payment.Id, userId);
        return new VerifyPaymentResponse(true);
    }
}

public sealed class RefundPaymentHandler : IRequestHandler<RefundPaymentCommand, RefundPaymentResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IPaymentGateway _gateway;
    private readonly ICurrentUserService _currentUser;

    public RefundPaymentHandler(IApplicationDbContext context, IPaymentGateway gateway, ICurrentUserService currentUser)
    {
        _context = context;
        _gateway = gateway;
        _currentUser = currentUser;
    }

    public async Task<RefundPaymentResponse> Handle(RefundPaymentCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var payment = await _context.Payments
            .FirstOrDefaultAsync(p => p.Id == request.PaymentId, cancellationToken);
        if (payment == null)
            throw new InvalidOperationException("Payment not found.");

        // Verify ownership
        var owns = payment.ServiceBookingId.HasValue
            ? await _context.ServiceBookings.AnyAsync(b => b.Id == payment.ServiceBookingId.Value && b.UserId == userId, cancellationToken)
            : payment.TransitTripId.HasValue
                ? await _context.TransitTrips.AnyAsync(t => t.Id == payment.TransitTripId.Value && t.UserId == userId, cancellationToken)
                : payment.LuggageDropOffId.HasValue
                    ? await _context.LuggageDropOffs.AnyAsync(l => l.Id == payment.LuggageDropOffId.Value && l.UserId == userId, cancellationToken)
                    : payment.ScooterRentalId.HasValue
                        ? await _context.ScooterRentals.AnyAsync(r => r.Id == payment.ScooterRentalId.Value && r.UserId == userId, cancellationToken)
                        : payment.FoodOrderId.HasValue
                            ? await _context.FoodOrders.AnyAsync(f => f.Id == payment.FoodOrderId.Value && f.UserId == userId, cancellationToken)
                            : false;

        if (!owns)
            throw new UnauthorizedAccessException("Access denied to this payment.");

        if (payment.Status != PaymentStatus.Captured)
            throw new InvalidOperationException("Only captured payments can be refunded.");

        // Prevent double refunds
        if (payment.Status == PaymentStatus.Refunded)
            throw new InvalidOperationException("Payment has already been refunded.");

        // Validate refund amount does not exceed the original payment amount
        if (request.Amount > payment.Amount)
            throw new InvalidOperationException("Refund amount cannot exceed the original payment amount.");

        var refundResult = await _gateway.RefundAsync(payment.ProviderPaymentId!, request.Amount, request.Reason, cancellationToken);
        if (!refundResult.Success)
            throw new InvalidOperationException($"Refund failed: {refundResult.ErrorMessage}");

        payment.MarkRefunded();
        await _context.SaveChangesAsync(cancellationToken);

        return new RefundPaymentResponse(true, refundResult.RefundId);
    }
}