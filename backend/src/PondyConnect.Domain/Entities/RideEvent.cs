namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Append-only audit log for ride lifecycle events. Enables trip timeline
/// reconstruction and receipts.
/// </summary>
public sealed class RideEvent : BaseEntity
{
    public Guid RideId { get; private set; }

    public RideEventType EventType { get; private set; }

    public DateTimeOffset Timestamp { get; private set; }

    public Guid? ActorUserId { get; private set; }

    /// <summary>
    /// Optional JSON-serialized metadata (e.g. driverId, location, fare breakdown).
    /// </summary>
    public string? Metadata { get; private set; }

    private RideEvent()
    {
    }

    public static RideEvent Create(
        Guid rideId,
        RideEventType eventType,
        Guid? actorUserId = null,
        string? metadata = null)
    {
        return new RideEvent
        {
            RideId = rideId,
            EventType = eventType,
            Timestamp = DateTimeOffset.UtcNow,
            ActorUserId = actorUserId,
            Metadata = metadata
        };
    }

    public static RideEvent CreateForSeed(
        Guid id,
        Guid rideId,
        RideEventType eventType,
        DateTimeOffset timestamp,
        Guid? actorUserId = null,
        string? metadata = null)
    {
        var evt = Create(rideId, eventType, actorUserId, metadata);
        evt.SetExplicitId(id);
        return evt;
    }
}
