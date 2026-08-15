namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A ride scheduled for a future time. Gets dispatched automatically
/// ~10 minutes before the scheduled pickup time.
/// </summary>
public sealed class ScheduledRide
{
    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public GeoLocation PickupLocation { get; private set; } = null!;
    public string PickupAddress { get; private set; } = string.Empty;
    public GeoLocation DropoffLocation { get; private set; } = null!;
    public string DropoffAddress { get; private set; } = string.Empty;
    public double DistanceKm { get; private set; }
    public VehicleType VehicleType { get; private set; }
    public PaymentMethod PaymentMethod { get; private set; }
    public DateTimeOffset ScheduledAt { get; private set; }
    public ScheduledRideStatus Status { get; private set; }
    public Guid? ResultingRideId { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public decimal EstimatedFare { get; private set; }

    private ScheduledRide() { }

    public static ScheduledRide Create(
        Guid userId,
        GeoLocation pickupLocation,
        string pickupAddress,
        GeoLocation dropoffLocation,
        string dropoffAddress,
        double distanceKm,
        VehicleType vehicleType,
        PaymentMethod paymentMethod,
        DateTimeOffset scheduledAt,
        decimal estimatedFare)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (scheduledAt < DateTimeOffset.UtcNow.AddMinutes(15))
            throw new ArgumentException("Scheduled time must be at least 15 minutes in the future.", nameof(scheduledAt));
        if (scheduledAt > DateTimeOffset.UtcNow.AddDays(30))
            throw new ArgumentException("Scheduled time must be within 30 days.", nameof(scheduledAt));

        return new ScheduledRide
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            PickupLocation = pickupLocation ?? throw new ArgumentNullException(nameof(pickupLocation)),
            PickupAddress = pickupAddress ?? throw new ArgumentNullException(nameof(pickupAddress)),
            DropoffLocation = dropoffLocation ?? throw new ArgumentNullException(nameof(dropoffLocation)),
            DropoffAddress = dropoffAddress ?? throw new ArgumentNullException(nameof(dropoffAddress)),
            DistanceKm = distanceKm,
            VehicleType = vehicleType,
            PaymentMethod = paymentMethod,
            ScheduledAt = scheduledAt,
            EstimatedFare = estimatedFare,
            Status = ScheduledRideStatus.Scheduled,
            CreatedAt = DateTimeOffset.UtcNow
        };
    }

    public void MarkDispatched(Guid rideId)
    {
        if (Status != ScheduledRideStatus.Scheduled)
            throw new InvalidOperationException("Only scheduled rides can be dispatched.");
        ResultingRideId = rideId;
        Status = ScheduledRideStatus.Dispatched;
    }

    public void Cancel()
    {
        if (Status is ScheduledRideStatus.Dispatched or ScheduledRideStatus.Completed)
            throw new InvalidOperationException("Cannot cancel a dispatched or completed scheduled ride.");
        Status = ScheduledRideStatus.Cancelled;
    }

    public bool IsReadyForDispatch => Status == ScheduledRideStatus.Scheduled &&
                                      DateTimeOffset.UtcNow >= ScheduledAt.AddMinutes(-10);
}

public enum ScheduledRideStatus
{
    Scheduled,
    Dispatched,
    Completed,
    Cancelled
}
