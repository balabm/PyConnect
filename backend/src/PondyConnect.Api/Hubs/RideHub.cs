namespace PondyConnect.Api.Hubs;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

/// <summary>
/// Rider-facing hub for real-time ride updates. Riders join a ride-specific
/// group to receive: DriverAssigned, DriverLocationUpdate, DriverArrived,
/// RideStarted, RideCompleted, RideCancelled, SosAlert.
/// Trip sharing uses token-gated public groups (no auth required).
/// </summary>
[Authorize]
public sealed class RideHub : Hub
{
    /// <summary>
    /// Join a ride-specific group to receive updates about a ride.
    /// </summary>
    public Task JoinRide(Guid rideId) => Groups.AddToGroupAsync(Context.ConnectionId, $"ride:{rideId}");

    public Task LeaveRide(Guid rideId) => Groups.RemoveFromGroupAsync(Context.ConnectionId, $"ride:{rideId}");

    /// <summary>
    /// Join a trip-share group using a share token (for live trip sharing
    /// with emergency contacts — no auth required for this method).
    /// </summary>
    [AllowAnonymous]
    public Task JoinTripShare(Guid tripShareToken) => Groups.AddToGroupAsync(Context.ConnectionId, $"tripshare:{tripShareToken}");

    [AllowAnonymous]
    public Task LeaveTripShare(Guid tripShareToken) => Groups.RemoveFromGroupAsync(Context.ConnectionId, $"tripshare:{tripShareToken}");
}
