namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A party service listing created by a vendor (DJ, bartender, catering,
/// sound system, lighting, photography, etc.). Consumers browse these
/// listings and submit booking requests via <see cref="PartyServiceBooking"/>.
/// </summary>
public sealed class PartyService : BaseEntity
{
    public Guid VendorId { get; private set; }

    public PartyServiceCategory Category { get; private set; }

    public string Title { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    /// <summary>
    /// Base price for the service. Pricing model is per <see cref="PricingUnit"/>
    /// (per hour, per event, per day, per plate).
    /// </summary>
    public decimal BasePrice { get; private set; }

    public string PricingUnit { get; private set; } = "per event";

    /// <summary>
    /// Minimum booking duration or quantity. For per-hour services this is
    /// the minimum number of hours (e.g. 3). For per-plate catering this is
    /// the minimum plate count (e.g. 50).
    /// </summary>
    public int MinimumBooking { get; private set; } = 1;

    /// <summary>
    /// Whether the vendor is currently accepting new bookings for this service.
    /// </summary>
    public bool IsAvailable { get; private set; } = true;

    public string? ImageUrl { get; private set; }

    /// <summary>
    /// Comma-separated tags for search and filtering (e.g. "wedding,birthday,corporate").
    /// </summary>
    public string? Tags { get; private set; }

    /// <summary>
    /// City / area where the service is offered.
    /// </summary>
    public string? ServiceArea { get; private set; }

    // ── Lifecycle ──

    private PartyService() { }

    public static PartyService Create(
        Guid vendorId,
        PartyServiceCategory category,
        string title,
        decimal basePrice,
        string pricingUnit = "per event",
        int minimumBooking = 1,
        string? description = null,
        string? imageUrl = null,
        string? tags = null,
        string? serviceArea = null)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(title);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(basePrice, nameof(basePrice));
        ArgumentOutOfRangeException.ThrowIfLessThan(minimumBooking, 1, nameof(minimumBooking));

        return new PartyService
        {
            VendorId = vendorId,
            Category = category,
            Title = title,
            BasePrice = basePrice,
            PricingUnit = pricingUnit,
            MinimumBooking = minimumBooking,
            Description = description,
            ImageUrl = imageUrl,
            Tags = tags,
            ServiceArea = serviceArea,
            IsAvailable = true,
        };
    }

    public void Update(
        decimal? basePrice = null,
        string? title = null,
        string? description = null,
        string? imageUrl = null,
        string? tags = null,
        string? serviceArea = null,
        bool? isAvailable = null,
        int? minimumBooking = null)
    {
        if (basePrice is not null && basePrice.Value > 0m) BasePrice = basePrice.Value;
        if (!string.IsNullOrWhiteSpace(title)) Title = title;
        if (description is not null) Description = description;
        if (imageUrl is not null) ImageUrl = imageUrl;
        if (tags is not null) Tags = tags;
        if (serviceArea is not null) ServiceArea = serviceArea;
        if (isAvailable is not null) IsAvailable = isAvailable.Value;
        if (minimumBooking is not null && minimumBooking.Value >= 1) MinimumBooking = minimumBooking.Value;
        MarkUpdated();
    }

    public void SetUnavailable() { IsAvailable = false; MarkUpdated(); }
    public void SetAvailable() { IsAvailable = true; MarkUpdated(); }
}

/// <summary>
/// A booking request from a consumer for a <see cref="PartyService"/>.
/// Tracks the event date, quantity (hours/plates/etc.), total price,
/// and booking status lifecycle.
/// </summary>
public sealed class PartyServiceBooking : BaseEntity
{
    public Guid ServiceId { get; private set; }
    public Guid UserId { get; private set; }
    public Guid VendorId { get; private set; }

    public DateTimeOffset EventDate { get; private set; }

    /// <summary>
    /// Number of hours, plates, days, or events booked (depending on pricing unit).
    /// </summary>
    public int Quantity { get; private set; }

    public decimal TotalAmount { get; private set; }

    public string? EventAddress { get; private set; }
    public string? Notes { get; private set; }

    /// <summary>
    /// Booking status: Pending → Confirmed → Completed (or Cancelled).
    /// </summary>
    public string Status { get; private set; } = "Pending";

    /// <summary>
    /// Payment status: Unpaid → Paid → Refunded.
    /// </summary>
    public string PaymentStatus { get; private set; } = "Unpaid";

    public string? RazorpayOrderId { get; private set; }
    public string? RazorpayPaymentId { get; private set; }

    public PartyService? Service { get; private set; }

    private PartyServiceBooking() { }

    public static PartyServiceBooking Create(
        Guid serviceId,
        Guid vendorId,
        Guid userId,
        DateTimeOffset eventDate,
        int quantity,
        decimal totalAmount,
        string? eventAddress = null,
        string? notes = null)
    {
        if (serviceId == Guid.Empty) throw new ArgumentException("Service ID is required.", nameof(serviceId));
        if (userId == Guid.Empty) throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentOutOfRangeException.ThrowIfLessThan(quantity, 1, nameof(quantity));
        ArgumentOutOfRangeException.ThrowIfNegative(totalAmount, nameof(totalAmount));

        return new PartyServiceBooking
        {
            ServiceId = serviceId,
            VendorId = vendorId,
            UserId = userId,
            EventDate = eventDate,
            Quantity = quantity,
            TotalAmount = totalAmount,
            EventAddress = eventAddress,
            Notes = notes,
            Status = "Pending",
            PaymentStatus = "Unpaid",
        };
    }

    public void Confirm() { Status = "Confirmed"; MarkUpdated(); }
    public void Complete() { Status = "Completed"; MarkUpdated(); }
    public void Cancel() { Status = "Cancelled"; MarkUpdated(); }

    public void RecordPayment(string razorpayOrderId, string razorpayPaymentId)
    {
        RazorpayOrderId = razorpayOrderId;
        RazorpayPaymentId = razorpayPaymentId;
        PaymentStatus = "Paid";
        MarkUpdated();
    }
}
