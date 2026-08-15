namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Financial settlement record for a captured payment, capturing the split
/// between vendor payout, driver payout and platform fee for transparent
/// zero-commission accounting.
/// </summary>
public sealed class PaymentSettlement : BaseEntity
{
    public Guid PaymentId { get; private set; }

    public Guid? ServiceBookingId { get; private set; }

    public Guid? FoodOrderId { get; private set; }

    public Guid? RideRequestId { get; private set; }

    public Guid? ScooterRentalId { get; private set; }

    public decimal GrossAmount { get; private set; }

    public decimal VendorPayout { get; private set; }

    public decimal DriverPayout { get; private set; }

    public decimal PlatformFee { get; private set; }

    public SettlementStatus SettlementStatus { get; private set; } = SettlementStatus.Pending;

    public DateTimeOffset? ProcessedAt { get; private set; }

    private PaymentSettlement()
    {
    }

    public static PaymentSettlement Create(
        Guid paymentId,
        decimal grossAmount,
        decimal vendorPayout,
        decimal driverPayout,
        decimal platformFee,
        Guid? serviceBookingId = null,
        Guid? foodOrderId = null,
        Guid? rideRequestId = null,
        Guid? scooterRentalId = null)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(grossAmount, nameof(grossAmount));
        ArgumentOutOfRangeException.ThrowIfNegative(vendorPayout, nameof(vendorPayout));
        ArgumentOutOfRangeException.ThrowIfNegative(driverPayout, nameof(driverPayout));
        ArgumentOutOfRangeException.ThrowIfNegative(platformFee, nameof(platformFee));

        return new PaymentSettlement
        {
            PaymentId = paymentId,
            ServiceBookingId = serviceBookingId,
            FoodOrderId = foodOrderId,
            RideRequestId = rideRequestId,
            ScooterRentalId = scooterRentalId,
            GrossAmount = grossAmount,
            VendorPayout = vendorPayout,
            DriverPayout = driverPayout,
            PlatformFee = platformFee,
            SettlementStatus = SettlementStatus.Processed,
            ProcessedAt = DateTimeOffset.UtcNow
        };
    }

    public void Reverse()
    {
        if (SettlementStatus != SettlementStatus.Processed)
            throw new InvalidOperationException("Only processed settlements can be reversed.");
        SettlementStatus = SettlementStatus.Reversed;
        MarkUpdated();
    }
}
