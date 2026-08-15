namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Intercity transit pickup booking: user provides arrival details, we dispatch a vehicle.
/// </summary>
public sealed class TransitTrip : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid? VendorId { get; private set; }

    public Guid HubId { get; private set; }

    public TransitHub Hub { get; private set; } = null!;

    public Vendor? Vendor { get; private set; }

    public string ArrivalFrom { get; private set; } = string.Empty;

    public string ArrivalMode { get; private set; } = string.Empty; // "Bus" | "Flight" | "Train"

    public DateTimeOffset ArrivalAt { get; private set; }

    public int PartySize { get; private set; }

    public string? DropOffLocation { get; private set; }

    public TransitStatus Status { get; private set; } = TransitStatus.Requested;

    public decimal Price { get; private set; }

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    public string? Notes { get; private set; }

    public DateTimeOffset? AssignedAt { get; private set; }

    public DateTimeOffset? StartedAt { get; private set; }

    public DateTimeOffset? CompletedAt { get; private set; }

    /// <summary>
    /// Optional driver name assigned by the taxi vendor to this trip.
    /// </summary>
    public string? DriverName { get; private set; }

    /// <summary>
    /// Optional vehicle plate assigned by the taxi vendor to this trip.
    /// </summary>
    public string? VehiclePlate { get; private set; }

    private TransitTrip()
    {
        // EF Core constructor.
    }

    public static TransitTrip Create(
        Guid userId,
        Guid hubId,
        string arrivalFrom,
        string arrivalMode,
        DateTimeOffset arrivalAt,
        int partySize,
        decimal price,
        Guid? vendorId = null,
        string? dropOffLocation = null,
        string? notes = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (hubId == Guid.Empty)
            throw new ArgumentException("Hub ID is required.", nameof(hubId));
        ArgumentException.ThrowIfNullOrWhiteSpace(arrivalFrom);
        ArgumentException.ThrowIfNullOrWhiteSpace(arrivalMode);
        if (arrivalAt < DateTimeOffset.UtcNow.AddMinutes(-5))
            throw new ArgumentException("Arrival time must be in the near future.", nameof(arrivalAt));
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(partySize, 0, nameof(partySize));
        ArgumentOutOfRangeException.ThrowIfNegative(price, nameof(price));

        return new TransitTrip
        {
            UserId = userId,
            HubId = hubId,
            ArrivalFrom = arrivalFrom,
            ArrivalMode = arrivalMode,
            ArrivalAt = arrivalAt,
            PartySize = partySize,
            Price = price,
            VendorId = vendorId,
            DropOffLocation = dropOffLocation,
            Notes = notes
        };
    }

    public void Assign(Guid vendorId)
    {
        if (Status != TransitStatus.Requested)
            throw new InvalidOperationException("Trip can only be assigned when requested.");
        VendorId = vendorId;
        Status = TransitStatus.Assigned;
        AssignedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Start()
    {
        if (Status != TransitStatus.Assigned)
            throw new InvalidOperationException("Trip can only start when assigned.");
        Status = TransitStatus.EnRoute;
        StartedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Complete()
    {
        if (Status is TransitStatus.Cancelled or TransitStatus.Completed)
            throw new InvalidOperationException("Trip already completed or cancelled.");
        Status = TransitStatus.Completed;
        CompletedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status is TransitStatus.Completed or TransitStatus.Cancelled)
            throw new InvalidOperationException("Trip already completed or cancelled.");
        Status = TransitStatus.Cancelled;
        MarkUpdated();
    }

    /// <summary>
    /// Assigns a driver and optional vehicle plate to this trip.
    /// Called by the taxi vendor when dispatching a vehicle.
    /// </summary>
    public void AssignDriver(string? driverName, string? vehiclePlate = null)
    {
        DriverName = driverName;
        VehiclePlate = vehiclePlate;
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