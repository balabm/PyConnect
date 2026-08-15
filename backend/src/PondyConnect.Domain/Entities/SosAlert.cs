namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// An SOS alert triggered by a rider during a ride. Links to support ticket
/// system and notifies emergency contacts via SMS.
/// </summary>
public sealed class SosAlert : BaseEntity
{
    public Guid RideId { get; private set; }

    public Guid UserId { get; private set; }

    public DateTimeOffset TriggeredAt { get; private set; }

    public DateTimeOffset? ResolvedAt { get; private set; }

    public Guid? ResolvedBy { get; private set; }

    public GeoLocation Location { get; private set; } = GeoLocation.Zero;

    public SosStatus Status { get; private set; } = SosStatus.Active;

    public string? Notes { get; private set; }

    private SosAlert()
    {
    }

    public static SosAlert Create(Guid rideId, Guid userId, GeoLocation location)
    {
        if (rideId == Guid.Empty)
            throw new ArgumentException("Ride ID is required.", nameof(rideId));
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));

        return new SosAlert
        {
            RideId = rideId,
            UserId = userId,
            Location = location,
            TriggeredAt = DateTimeOffset.UtcNow,
            Status = SosStatus.Active
        };
    }

    public void Resolve(Guid resolvedByUserId, SosStatus status = SosStatus.Resolved, string? notes = null)
    {
        if (Status != SosStatus.Active)
            throw new InvalidOperationException("SOS alert is not active.");

        Status = status;
        ResolvedAt = DateTimeOffset.UtcNow;
        ResolvedBy = resolvedByUserId;
        Notes = notes;
        MarkUpdated();
    }
}
