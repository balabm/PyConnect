namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Service for broadcasting ride events to riders via RideHub.
/// Also handles legacy broadcast for backward compatibility.
/// </summary>
public sealed class RideDispatchService
{
    private readonly IHubContext<DriverHub> _driverHub;
    private readonly IHubContext<RideHub> _rideHub;
    private readonly IApplicationDbContext _context;
    private readonly DispatchEngine _dispatchEngine;

    public RideDispatchService(
        IHubContext<DriverHub> driverHub,
        IHubContext<RideHub> rideHub,
        IApplicationDbContext context,
        DispatchEngine dispatchEngine)
    {
        _driverHub = driverHub;
        _rideHub = rideHub;
        _context = context;
        _dispatchEngine = dispatchEngine;
    }

    /// <summary>
    /// Dispatch a ride request to nearby drivers using the sequential
    /// offer queue engine. Rings the closest driver first, gives them
    /// 15 seconds to accept, then moves to the next. Expands radius by
    /// 2km after 3 failed rings.
    ///
    /// The dispatch runs as a background task — this method returns
    /// immediately after starting the sequential ringing.
    /// </summary>
    public async Task BroadcastRideRequestAsync(Guid rideId, CancellationToken cancellationToken = default)
    {
        // Fire-and-forget the sequential dispatch as a background task.
        // The HTTP request returns immediately; the sequential ringing
        // continues asynchronously until a driver accepts or the pool
        // is exhausted.
        _ = Task.Run(() => _dispatchEngine.DispatchRideSequentialAsync(rideId, cancellationToken: cancellationToken), cancellationToken);

        await Task.CompletedTask;
    }

    /// <summary>
    /// Notify the rider that a driver has been assigned to their ride.
    /// Pushes via RideHub to the ride-specific group.
    /// </summary>
    public async Task NotifyDriverAssignedAsync(
        Guid rideId,
        Guid driverId,
        string driverName,
        string vehicleType,
        string? vehiclePlate,
        double rating,
        int totalRides,
        double? distanceToPickupKm,
        int? etaToPickupMin,
        CancellationToken cancellationToken = default)
    {
        var notification = new DriverAssignedNotification(
            rideId, driverId, driverName, vehicleType, vehiclePlate,
            rating, totalRides, distanceToPickupKm, etaToPickupMin);

        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("DriverAssigned", notification, cancellationToken);

        // Also notify other drivers that this ride is no longer available
        await _driverHub.Clients.Group("drivers")
            .SendAsync("RideAccepted", new RideAcceptedNotification(rideId, driverId, driverName), cancellationToken);
    }

    /// <summary>
    /// Notify the rider of a driver location update (for live tracking).
    /// </summary>
    public async Task NotifyDriverLocationUpdateAsync(
        Guid rideId,
        double latitude,
        double longitude,
        double? heading,
        double? distanceToPickupKm,
        int? etaToPickupMin,
        CancellationToken cancellationToken = default)
    {
        var update = new DriverLocationUpdate(
            rideId, latitude, longitude, heading, distanceToPickupKm, etaToPickupMin, DateTimeOffset.UtcNow);

        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("DriverLocationUpdate", update, cancellationToken);

        // Also push to trip-share group if trip sharing is enabled
        var ride = await _context.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == rideId, cancellationToken);
        if (ride?.TripShareToken != null)
        {
            await _rideHub.Clients.Group($"tripshare:{ride.TripShareToken}")
                .SendAsync("DriverLocationUpdate", update, cancellationToken);
        }
    }

    /// <summary>
    /// Notify the rider that the driver has arrived at pickup.
    /// </summary>
    public async Task NotifyDriverArrivedAsync(Guid rideId, CancellationToken cancellationToken = default)
    {
        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("DriverArrived", new { RideId = rideId }, cancellationToken);
    }

    /// <summary>
    /// Notify the rider that the ride has started.
    /// </summary>
    public async Task NotifyRideStartedAsync(Guid rideId, CancellationToken cancellationToken = default)
    {
        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("RideStarted", new { RideId = rideId, StartedAt = DateTimeOffset.UtcNow }, cancellationToken);
    }

    /// <summary>
    /// Notify the rider that the ride has been completed.
    /// </summary>
    public async Task NotifyRideCompletedAsync(Guid rideId, CancellationToken cancellationToken = default)
    {
        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("RideCompleted", new { RideId = rideId, CompletedAt = DateTimeOffset.UtcNow }, cancellationToken);
    }

    /// <summary>
    /// Notify the rider that the ride has been cancelled.
    /// </summary>
    public async Task NotifyRideCancelledAsync(Guid rideId, string reason, CancellationToken cancellationToken = default)
    {
        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("RideCancelled", new { RideId = rideId, Reason = reason, CancelledAt = DateTimeOffset.UtcNow }, cancellationToken);
    }

    /// <summary>
    /// Notify the rider of an SOS alert.
    /// </summary>
    public async Task NotifySosAlertAsync(Guid rideId, Guid sosAlertId, CancellationToken cancellationToken = default)
    {
        await _rideHub.Clients.Group($"ride:{rideId}")
            .SendAsync("SosAlert", new { RideId = rideId, SosAlertId = sosAlertId, TriggeredAt = DateTimeOffset.UtcNow }, cancellationToken);
    }
}

public sealed record RideAcceptedNotification(Guid RideId, Guid DriverId, string DriverName);

public sealed record DriverAssignedNotification(
    Guid RideId,
    Guid DriverId,
    string DriverName,
    string VehicleType,
    string? VehiclePlate,
    double Rating,
    int TotalRides,
    double? DistanceToPickupKm,
    int? EtaToPickupMin);

public sealed record DriverLocationUpdate(
    Guid RideId,
    double Latitude,
    double Longitude,
    double? Heading,
    double? DistanceToPickupKm,
    int? EtaToPickupMin,
    DateTimeOffset ServerTimestamp);
