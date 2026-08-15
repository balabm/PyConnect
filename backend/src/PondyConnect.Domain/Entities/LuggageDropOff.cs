namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Luggage cloak drop-off slot at a partner vendor.
/// </summary>
public sealed class LuggageDropOff : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid VendorId { get; private set; }

    public Vendor Vendor { get; private set; } = null!;

    public DateTimeOffset ScheduledFor { get; private set; }

    public DateTimeOffset DroppedAt { get; private set; }

    public DateTimeOffset? PickedUpAt { get; private set; }

    public int BagCount { get; private set; }

    public decimal RatePerHour { get; private set; }

    public decimal TotalAmount { get; private set; }

    public LuggageStatus Status { get; private set; } = LuggageStatus.Reserved;

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    public string? Notes { get; private set; }

    private LuggageDropOff()
    {
        // EF Core constructor.
    }

    public static LuggageDropOff Create(
        Guid userId,
        Guid vendorId,
        DateTimeOffset scheduledFor,
        DateTimeOffset droppedAt,
        int bagCount,
        decimal ratePerHour,
        string? notes = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        if (scheduledFor < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Scheduled time must be in the near future.", nameof(scheduledFor));
        if (droppedAt < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Drop time must be in the near future.", nameof(droppedAt));
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(bagCount, 0, nameof(bagCount));
        ArgumentOutOfRangeException.ThrowIfNegative(ratePerHour, nameof(ratePerHour));

        var total = ratePerHour * bagCount; // simplified hourly per bag
        return new LuggageDropOff
        {
            UserId = userId,
            VendorId = vendorId,
            ScheduledFor = scheduledFor,
            DroppedAt = droppedAt,
            BagCount = bagCount,
            RatePerHour = ratePerHour,
            TotalAmount = total,
            Notes = notes
        };
    }

    public void MarkDropped()
    {
        if (Status != LuggageStatus.Reserved)
            throw new InvalidOperationException("Only reserved slots can be marked dropped.");
        Status = LuggageStatus.Dropped;
        MarkUpdated();
    }

    public void MarkCollected()
    {
        if (Status != LuggageStatus.Dropped)
            throw new InvalidOperationException("Only dropped luggage can be collected.");
        Status = LuggageStatus.Collected;
        PickedUpAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is LuggageStatus.Collected or LuggageStatus.Cancelled)
            throw new InvalidOperationException("Cannot cancel after collection or if already cancelled.");
        Status = LuggageStatus.Cancelled;
        MarkUpdated();
    }

    public void RecordPayment(PaymentStatus paymentStatus, string paymentReference)
    {
        if (string.IsNullOrWhiteSpace(paymentReference))
            throw new ArgumentException("Payment reference is required.", nameof(paymentReference));
        PaymentStatus = paymentStatus;
        PaymentReference = paymentReference;
        MarkUpdated();
    }
}