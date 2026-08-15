namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Aggregates booking lines for a user. Covers every service stream
/// (Transit, Nightlife, Luggage, Rental, Experience) and tracks its
/// lifecycle, price and payment status over time.
/// </summary>
public sealed class ServiceBooking : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid? VendorId { get; private set; }

    public ServiceType ServiceType { get; private set; }

    public BookingStatus Status { get; private set; } = BookingStatus.Pending;

    public decimal TotalAmount { get; private set; }

    public string Currency { get; private set; } = "INR";

    public DateTimeOffset ScheduledFor { get; private set; }

    public DateTimeOffset? CompletedAt { get; private set; }

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    public string? Notes { get; private set; }

    public DateOnly? CheckInDate { get; private set; }

    public DateOnly? CheckOutDate { get; private set; }

    public Guid? HomestayId { get; private set; }

    public Guid? VenueId { get; private set; }

    public int SeatCount { get; private set; }

    public string? PassToken { get; private set; }

    public IReadOnlyCollection<BookingItem> Items => _items.AsReadOnly();

    private readonly List<BookingItem> _items = [];

    private ServiceBooking()
    {
        // EF Core constructor.
    }

    public static ServiceBooking Create(
        Guid userId,
        ServiceType serviceType,
        DateTimeOffset scheduledFor,
        Guid? vendorId = null,
        decimal amount = 0m,
        string? notes = null,
        DateOnly? checkInDate = null,
        DateOnly? checkOutDate = null,
        Guid? homestayId = null,
        Guid? venueId = null,
        int seatCount = 0)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (scheduledFor < DateTimeOffset.UnixEpoch)
            throw new ArgumentOutOfRangeException(nameof(scheduledFor), "Scheduled time is invalid.");
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        ArgumentOutOfRangeException.ThrowIfNegative(seatCount, nameof(seatCount));

        var booking = new ServiceBooking
        {
            UserId = userId,
            VendorId = vendorId,
            ServiceType = serviceType,
            ScheduledFor = scheduledFor,
            TotalAmount = amount,
            Notes = notes,
            CheckInDate = checkInDate,
            CheckOutDate = checkOutDate,
            HomestayId = homestayId,
            VenueId = venueId,
            SeatCount = seatCount
        };
        return booking;
    }

    public void AddItem(string name, int quantity, decimal unitPrice)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(quantity, 0, nameof(quantity));
        ArgumentOutOfRangeException.ThrowIfNegative(unitPrice, nameof(unitPrice));

        _items.Add(BookingItem.Create(name, quantity, unitPrice));
        RecalculateTotal();
        MarkUpdated();
    }

    public void Confirm()
    {
        if (Status is BookingStatus.Cancelled or BookingStatus.Expired)
            throw new InvalidOperationException("A cancelled/expired booking cannot be confirmed.");
        Status = BookingStatus.Confirmed;
        MarkUpdated();
    }

    public void CheckIn()
    {
        if (Status != BookingStatus.Confirmed)
            throw new InvalidOperationException("Only confirmed bookings can be checked in.");
        Status = BookingStatus.CheckedIn;
        MarkUpdated();
    }

    public void Complete()
    {
        if (Status is BookingStatus.Cancelled)
            throw new InvalidOperationException("A cancelled booking cannot be completed.");
        Status = BookingStatus.Completed;
        CompletedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is BookingStatus.Completed)
            throw new InvalidOperationException("A completed booking cannot be cancelled.");
        if (Status is BookingStatus.Cancelled)
            return;
        Status = BookingStatus.Cancelled;
        MarkUpdated();
    }

    public void RecordPayment(PaymentStatus paymentStatus, string paymentReference)
    {
        if (string.IsNullOrWhiteSpace(paymentReference))
            throw new ArgumentException("Payment reference is required when marking a payment.", nameof(paymentReference));
        PaymentStatus = paymentStatus;
        PaymentReference = paymentReference;
        MarkUpdated();
    }

    public void IssuePassToken(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        PassToken = token;
        MarkUpdated();
    }

    private void RecalculateTotal()
        => TotalAmount = _items.Sum(i => i.LineTotal);
}

/// <summary>
/// Line item inside a ServiceBooking (e.g. cover charge, pickup leg,
/// hours of luggage storage).
/// </summary>
public sealed class BookingItem : BaseEntity
{
    public Guid ServiceBookingId { get; private set; }

    public string Description { get; private set; } = string.Empty;

    public int Quantity { get; private set; }

    public decimal UnitPrice { get; private set; }

    public decimal LineTotal => Quantity * UnitPrice;

    private BookingItem()
    {
        // EF Core constructor.
    }

    public static BookingItem Create(string description, int quantity, decimal unitPrice)
        => new()
        {
            Description = description,
            Quantity = quantity,
            UnitPrice = unitPrice
        };
}