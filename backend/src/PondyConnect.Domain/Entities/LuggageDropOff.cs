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

    /// <summary>
    /// Photo of the bags taken by the Partner at drop-off. Protects
    /// Partners from liability disputes ("my laptop is missing").
    /// Displayed on the Consumer app for transparency.
    /// </summary>
    public string? IntakeImageUrl { get; private set; }

    /// <summary>
    /// Time-sensitive 6-digit PIN generated for secure retrieval.
    /// The Partner must scan the QR or manually enter this PIN to
    /// transition the status to Collected.
    /// </summary>
    public string? RetrievalPin { get; private set; }

    /// <summary>
    /// When the retrieval PIN was generated (for expiry validation).
    /// </summary>
    public DateTimeOffset? RetrievalPinGeneratedAt { get; private set; }

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

    /// <summary>
    /// Marks the luggage as dropped off and records the intake photo.
    /// The Partner must photograph the bags with security tags to
    /// protect against liability disputes.
    /// </summary>
    public void MarkDropped(string? intakeImageUrl = null)
    {
        if (Status != LuggageStatus.Reserved)
            throw new InvalidOperationException("Only reserved slots can be marked dropped.");
        Status = LuggageStatus.Dropped;
        IntakeImageUrl = intakeImageUrl;
        MarkUpdated();
    }

    /// <summary>
    /// Generates a time-sensitive 6-digit retrieval PIN. Called when
    /// the Consumer is ready to pick up their bags. The PIN expires
    /// after 10 minutes.
    /// </summary>
    public void GenerateRetrievalPin()
    {
        if (Status != LuggageStatus.Dropped)
            throw new InvalidOperationException("Retrieval PIN can only be generated for dropped luggage.");

        RetrievalPin = Random.Shared.Next(100000, 999999).ToString(System.Globalization.CultureInfo.InvariantCulture);
        RetrievalPinGeneratedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Collects the luggage using the retrieval PIN. The Partner must
    /// scan the QR code or manually enter the PIN. Closes the liability
    /// loop.
    /// </summary>
    public void CollectWithPin(string pin)
    {
        if (Status != LuggageStatus.Dropped)
            throw new InvalidOperationException("Only dropped luggage can be collected.");

        if (string.IsNullOrEmpty(RetrievalPin))
            throw new InvalidOperationException("No retrieval PIN has been generated. Ask the customer to generate one.");

        // PIN expires after 10 minutes
        if (RetrievalPinGeneratedAt is { } generatedAt &&
            DateTimeOffset.UtcNow - generatedAt > TimeSpan.FromMinutes(10))
            throw new InvalidOperationException("Retrieval PIN has expired. Ask the customer to generate a new one.");

        if (!string.Equals(RetrievalPin, pin, StringComparison.Ordinal))
            throw new InvalidOperationException("Invalid retrieval PIN.");

        Status = LuggageStatus.Collected;
        PickedUpAt = DateTimeOffset.UtcNow;
        RetrievalPin = null; // Clear the PIN after successful collection
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