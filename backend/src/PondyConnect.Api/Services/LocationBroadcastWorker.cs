namespace PondyConnect.Api.Services;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background worker that broadcasts driver location updates to consumers
/// in real-time via SignalR. Runs every 3 seconds, queries all active rides
/// (EnRoute status), gets the driver's latest GPS from <see cref="DriverLocationStore"/>,
/// and pushes the update to the ride's SignalR group via
/// <see cref="RideDispatchService.NotifyDriverLocationUpdateAsync"/>.
///
/// This bridges the gap between the driver's SignalR UpdateLocation pings
/// (stored in-memory) and the consumer's RideHub subscription that expects
/// DriverLocationUpdate events.
/// </summary>
public sealed class LocationBroadcastWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<LocationBroadcastWorker> _logger;
    private static readonly TimeSpan BroadcastInterval = TimeSpan.FromSeconds(3);

    public LocationBroadcastWorker(
        IServiceProvider serviceProvider,
        ILogger<LocationBroadcastWorker> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("LocationBroadcastWorker started — broadcasting driver GPS every {Interval}s", BroadcastInterval.TotalSeconds);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                var locationStore = scope.ServiceProvider.GetRequiredService<DriverLocationStore>();
                var rideDispatch = scope.ServiceProvider.GetRequiredService<RideDispatchService>();

                // Query all active rides where the driver is en route to pickup or destination
                var activeRides = await context.RideRequests
                    .AsNoTracking()
                    .Where(r => r.Status == RideStatus.DriverAssigned
                             || r.Status == RideStatus.EnRoute
                             || r.Status == RideStatus.ArrivedAtPickup)
                    .Select(r => new { r.Id, r.DriverId, r.PickupLocation, r.Status })
                    .ToListAsync(stoppingToken);

                foreach (var ride in activeRides)
                {
                    if (ride.DriverId == null || ride.DriverId == Guid.Empty)
                        continue;

                    var driverLoc = locationStore.Get(ride.DriverId.Value);
                    if (driverLoc is null || !driverLoc.IsOnline)
                        continue;

                    // Skip stale entries — driver GPS may have died
                    if (DateTimeOffset.UtcNow - driverLoc.UpdatedAt > TimeSpan.FromSeconds(30))
                        continue;

                    // Calculate distance and ETA to pickup if driver hasn't picked up yet
                    double? distanceToPickupKm = null;
                    int? etaToPickupMin = null;

                    if (ride.Status == RideStatus.DriverAssigned || ride.Status == RideStatus.ArrivedAtPickup)
                    {
                        distanceToPickupKm = ride.PickupLocation.DistanceKm(
                            PondyConnect.Domain.ValueObjects.GeoLocation.Create(driverLoc.Latitude, driverLoc.Longitude));
                        // Rough ETA: assume 18 km/h average city speed
                        etaToPickupMin = (int)Math.Ceiling(distanceToPickupKm.Value / 18.0 * 60);
                    }

                    await rideDispatch.NotifyDriverLocationUpdateAsync(
                        rideId: ride.Id,
                        latitude: driverLoc.Latitude,
                        longitude: driverLoc.Longitude,
                        heading: driverLoc.Heading,
                        distanceToPickupKm: distanceToPickupKm,
                        etaToPickupMin: etaToPickupMin,
                        cancellationToken: stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in LocationBroadcastWorker iteration");
            }

            await Task.Delay(BroadcastInterval, stoppingToken);
        }
    }
}
