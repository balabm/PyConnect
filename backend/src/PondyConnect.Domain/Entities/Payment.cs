namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Unified payment record for any booking/service.
/// </summary>
public sealed class Payment : BaseEntity
{
    public Guid? ServiceBookingId { get; private set; }

    public Guid? TransitTripId { get; private set; }

    public Guid? LuggageDropOffId { get; private set; }

    public Guid? ScooterRentalId { get; private set; }

    public Guid? FoodOrderId { get; private set; }

    public decimal Amount { get; private set; }

    public string Currency { get; private set; } = "INR";

    public PaymentProvider Provider { get; private set; }

    public PaymentMethod Method { get; private set; }

    public string? ProviderOrderId { get; private set; }

    public string? ProviderPaymentId { get; private set; }

    public PaymentStatus Status { get; private set; } = PaymentStatus.Unpaid;

    public string? FailureReason { get; private set; }

    public DateTimeOffset? CapturedAt { get; private set; }

    public DateTimeOffset? RefundedAt { get; private set; }

    private Payment()
    {
        // EF Core constructor.
    }

    public static Payment CreateForServiceBooking(
        Guid serviceBookingId,
        decimal amount,
        PaymentProvider provider = PaymentProvider.Razorpay,
        PaymentMethod method = PaymentMethod.Upi)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        return new Payment
        {
            ServiceBookingId = serviceBookingId,
            Amount = amount,
            Provider = provider,
            Method = method
        };
    }

    public static Payment CreateForTransitTrip(
        Guid transitTripId,
        decimal amount,
        PaymentProvider provider = PaymentProvider.Razorpay,
        PaymentMethod method = PaymentMethod.Upi)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        return new Payment
        {
            TransitTripId = transitTripId,
            Amount = amount,
            Provider = provider,
            Method = method
        };
    }

    public static Payment CreateForLuggageDropOff(
        Guid luggageDropOffId,
        decimal amount,
        PaymentProvider provider = PaymentProvider.Razorpay,
        PaymentMethod method = PaymentMethod.Upi)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        return new Payment
        {
            LuggageDropOffId = luggageDropOffId,
            Amount = amount,
            Provider = provider,
            Method = method
        };
    }

    public static Payment CreateForScooterRental(
        Guid scooterRentalId,
        decimal amount,
        PaymentProvider provider = PaymentProvider.Razorpay,
        PaymentMethod method = PaymentMethod.Upi)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        return new Payment
        {
            ScooterRentalId = scooterRentalId,
            Amount = amount,
            Provider = provider,
            Method = method
        };
    }

    public static Payment CreateForFoodOrder(
        Guid foodOrderId,
        decimal amount,
        PaymentProvider provider = PaymentProvider.Razorpay,
        PaymentMethod method = PaymentMethod.Upi)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        return new Payment
        {
            FoodOrderId = foodOrderId,
            Amount = amount,
            Provider = provider,
            Method = method
        };
    }

    public void MarkProviderOrderCreated(string providerOrderId)
    {
        if (string.IsNullOrWhiteSpace(providerOrderId))
            throw new ArgumentException("Provider order ID is required.", nameof(providerOrderId));
        ProviderOrderId = providerOrderId;
        MarkUpdated();
    }

    public void MarkCaptured(string providerPaymentId)
    {
        if (string.IsNullOrWhiteSpace(providerPaymentId))
            throw new ArgumentException("Provider payment ID is required.", nameof(providerPaymentId));
        Status = PaymentStatus.Captured;
        ProviderPaymentId = providerPaymentId;
        CapturedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void MarkFailed(string reason)
    {
        Status = PaymentStatus.Failed;
        FailureReason = reason;
        MarkUpdated();
    }

    public void MarkRefunded()
    {
        if (Status != PaymentStatus.Captured)
            throw new InvalidOperationException("Only captured payments can be refunded.");
        Status = PaymentStatus.Refunded;
        RefundedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}