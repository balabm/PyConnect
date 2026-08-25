namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A surge zone identified by the demand prediction engine. Color-coded by
/// intensity: Yellow (moderate demand), Orange (high demand), Red (surge).
/// </summary>
public sealed record SurgeZone(
    double Latitude,
    double Longitude,
    string AreaName,
    int PendingOrders,
    int ActiveDrivers,
    double DemandSupplyRatio,
    SurgeLevel Level,
    decimal SurgeBonus);

public enum SurgeLevel { Low, Moderate, High, Surge }

/// <summary>
/// Background service that runs every 5 minutes, analyzing pending ride
/// requests and food orders against the available driver supply. Generates
/// surge zones and pushes them to idle drivers via SignalR.
/// </summary>
public sealed class DemandPredictionService : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly IHubContext<DriverHub> _hubContext;
    private readonly DriverLocationStore _locationStore;
    private readonly ILogger<DemandPredictionService> _logger;

    // Pondicherry service area center
    private const double CityCenterLat = 11.9356;
    private const double CityCenterLng = 79.8301;
    private const double ServiceRadiusKm = 50.0;

    // Grid cell size in km (approximate)
    private const double CellSizeKm = 2.0;

    // Minimum orders to consider a cell as having demand
    private const int MinOrdersForDemand = 3;

    // Surge bonus tiers
    private const decimal ModerateBonus = 10m;
    private const decimal HighBonus = 20m;
    private const decimal SurgeBonus = 40m;

    // Well-known area names in Pondicherry for labeling
    private static readonly (double Lat, double Lng, string Name)[] KnownAreas =
    {
        (11.9356, 79.8301, "Puducherry City Center"),
        (11.9310, 79.8350, "White Town"),
        (11.9410, 79.8080, "Lawspet"),
        (11.9490, 79.8030, "Oulgaret"),
        (11.9590, 79.8370, "Auroville Road"),
        (11.9230, 79.8300, "Heritage Quarter"),
        (11.9620, 79.8330, "Auroville"),
        (11.9100, 79.8100, "Villianur"),
        (11.9380, 79.8450, "Rock Beach"),
        (11.9360, 79.8200, "Muthialpet"),
    };

    public DemandPredictionService(
        IServiceProvider serviceProvider,
        IHubContext<DriverHub> hubContext,
        DriverLocationStore locationStore,
        ILogger<DemandPredictionService> logger)
    {
        _serviceProvider = serviceProvider;
        _hubContext = hubContext;
        _locationStore = locationStore;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        // Wait 30 seconds after startup before first run
        await Task.Delay(TimeSpan.FromSeconds(30), stoppingToken);

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await ComputeAndPushSurgeZonesAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error computing surge zones");
            }

            await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
        }
    }

    private async Task ComputeAndPushSurgeZonesAsync(CancellationToken ct)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

        // Gather pending ride requests (searching, accepted, en route to pickup)
        var pendingRides = await context.RideRequests.AsNoTracking()
            .Where(r => r.Status == RideStatus.Searching
                     || r.Status == RideStatus.DriverAssigned
                     || r.Status == RideStatus.ArrivedAtPickup)
            .Select(r => new { r.PickupLocation, r.Fare })
            .ToListAsync(ct);

        // Gather pending food orders (placed, accepted, preparing, out for delivery)
        var pendingFoodOrders = await context.FoodOrders.AsNoTracking()
            .Where(o => o.Status == FoodOrderStatus.Placed
                     || o.Status == FoodOrderStatus.Accepted
                     || o.Status == FoodOrderStatus.Preparing
                     || o.Status == FoodOrderStatus.OutForDelivery)
            .Select(o => new { o.DeliveryLocation, o.TotalAmount })
            .ToListAsync(ct);

        // Get all online drivers from the in-memory store
        var onlineDrivers = _locationStore.GetOnlineDrivers();
        var idleDrivers = onlineDrivers.Where(d => !d.IsOnRide).ToList();

        // Cluster demand points into grid cells
        var demandPoints = new List<(double Lat, double Lng)>();
        foreach (var ride in pendingRides)
            demandPoints.Add((ride.PickupLocation.Latitude, ride.PickupLocation.Longitude));
        foreach (var order in pendingFoodOrders)
            demandPoints.Add((order.DeliveryLocation.Latitude, order.DeliveryLocation.Longitude));

        var zones = new List<SurgeZone>();

        // Group demand points into grid cells
        var gridCells = demandPoints
            .GroupBy(p => (
                CellLat: Math.Round(p.Lat / (CellSizeKm / 111.0)),
                CellLng: Math.Round(p.Lng / (CellSizeKm / (111.0 * Math.Cos(CityCenterLat * Math.PI / 180.0))))
            ))
            .ToList();

        foreach (var cell in gridCells)
        {
            var orderCount = cell.Count();
            if (orderCount < MinOrdersForDemand) continue;

            // Calculate cell center
            var avgLat = cell.Average(p => p.Lat);
            var avgLng = cell.Average(p => p.Lng);

            // Count drivers within 2km of this cell center
            var cellCenter = GeoLocation.Create(avgLat, avgLng);
            var nearbyDrivers = idleDrivers.Count(d =>
            {
                var driverLoc = GeoLocation.Create(d.Latitude, d.Longitude);
                return cellCenter.DistanceKm(driverLoc) <= 3.0;
            });

            var ratio = nearbyDrivers > 0
                ? (double)orderCount / nearbyDrivers
                : orderCount * 2.0; // No drivers = very high demand

            if (ratio < 1.5) continue; // Not enough demand relative to supply

            var (level, bonus) = ratio switch
            {
                >= 5.0 => (SurgeLevel.Surge, SurgeBonus),
                >= 3.0 => (SurgeLevel.High, HighBonus),
                >= 2.0 => (SurgeLevel.Moderate, ModerateBonus),
                _ => (SurgeLevel.Low, 0m)
            };

            if (level == SurgeLevel.Low) continue;

            // Find nearest known area name
            var areaName = FindNearestArea(avgLat, avgLng);

            zones.Add(new SurgeZone(
                Math.Round(avgLat, 4),
                Math.Round(avgLng, 4),
                areaName,
                orderCount,
                nearbyDrivers,
                Math.Round(ratio, 1),
                level,
                bonus));
        }

        // Sort by demand/supply ratio descending, take top 10
        zones = zones.OrderByDescending(z => z.DemandSupplyRatio).Take(10).ToList();

        if (zones.Count > 0)
        {
            _logger.LogInformation("Pushing {Count} surge zones to idle drivers", zones.Count);

            // Push to all connected drivers via SignalR
            await _hubContext.Clients.Group("drivers").SendAsync("SurgeZonesUpdated", zones.Select(z => new
            {
                latitude = z.Latitude,
                longitude = z.Longitude,
                areaName = z.AreaName,
                pendingOrders = z.PendingOrders,
                activeDrivers = z.ActiveDrivers,
                demandSupplyRatio = z.DemandSupplyRatio,
                level = z.Level.ToString(),
                surgeBonus = z.SurgeBonus
            }), ct);
        }
    }

    private static string FindNearestArea(double lat, double lng)
    {
        var minDist = double.MaxValue;
        var nearest = "Puducherry";

        foreach (var area in KnownAreas)
        {
            var dLat = area.Lat - lat;
            var dLng = area.Lng - lng;
            var dist = dLat * dLat + dLng * dLng;
            if (dist < minDist)
            {
                minDist = dist;
                nearest = area.Name;
            }
        }

        return nearest;
    }
}
