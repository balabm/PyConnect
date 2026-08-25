namespace PondyConnect.Domain.Enums;

/// <summary>
/// Lifecycle of a peer-to-peer (user-hosted) private event.
/// </summary>
public enum P2pEventStatus
{
    Draft = 1,
    Published = 2,
    SoldOut = 3,
    Completed = 4,
    Cancelled = 5
}
