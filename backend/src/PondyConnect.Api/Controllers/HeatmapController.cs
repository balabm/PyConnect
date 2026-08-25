namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Services;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Driver-facing heatmap / demand prediction endpoints. Returns current
/// surge zones so idle drivers can navigate to high-demand areas.
/// </summary>
[ApiController]
[Route("api/heatmap")]
[Authorize(Roles = "Driver")]
public sealed class HeatmapController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly DriverLocationStore _locationStore;
    private readonly ILogger<HeatmapController> _logger;

    private const double CellSizeKm = 2.0;
    private const int MinOrdersForDemand = 2;

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

    public HeatmapController(
        IApplicationDbContext context,
        DriverLocationStore locationStore,
        ILogger<HeatmapController> logger)
    {
        _context = context;
        _locationStore = locationStore;
        _logger = logger;
    }

    /// <summary>
    /// Returns the current surge zones for the driver heatmap. Each zone
    /// includes the geographic center, demand/supply ratio, surge level,
    /// and bonus amount.
    /// </summary>
    [HttpGet("surge-zones")]
    [ProducesResponseType(typeof(IReadOnlyList<SurgeZoneResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SurgeZoneResponse>>> GetSurgeZones(CancellationToken ct)
    {
        // Gather pending rides
        var pendingRides = await _context.RideRequests.AsNoTracking()
            .Where(r => r.Status == RideStatus.Searching
                     || r.Status == RideStatus.DriverAssigned
                     || r.Status == RideStatus.ArrivedAtPickup)
            .Select(r => new { r.PickupLocation, r.Fare })
            .ToListAsync(ct);

        // Gather pending food orders
        var pendingFoodOrders = await _context.FoodOrders.AsNoTracking()
            .Where(o => o.Status == FoodOrderStatus.Placed
                     || o.Status == FoodOrderStatus.Accepted
                     || o.Status == FoodOrderStatus.Preparing
                     || o.Status == FoodOrderStatus.OutForDelivery)
            .Select(o => new { o.DeliveryLocation, o.TotalAmount })
            .ToListAsync(ct);

        // Get online idle drivers
        var onlineDrivers = _locationStore.GetOnlineDrivers();
        var idleDrivers = onlineDrivers.Where(d => !d.IsOnRide).ToList();

        // Cluster demand points
        var demandPoints = new List<(double Lat, double Lng)>();
        foreach (var ride in pendingRides)
            demandPoints.Add((ride.PickupLocation.Latitude, ride.PickupLocation.Longitude));
        foreach (var order in pendingFoodOrders)
            demandPoints.Add((order.DeliveryLocation.Latitude, order.DeliveryLocation.Longitude));

        var gridCells = demandPoints
            .GroupBy(p => (
                CellLat: Math.Round(p.Lat / (CellSizeKm / 111.0)),
                CellLng: Math.Round(p.Lng / (CellSizeKm / (111.0 * Math.Cos(11.9356 * Math.PI / 180.0))))
            ))
            .ToList();

        var zones = new List<SurgeZoneResponse>();

        foreach (var cell in gridCells)
        {
            var orderCount = cell.Count();
            if (orderCount < MinOrdersForDemand) continue;

            var avgLat = cell.Average(p => p.Lat);
            var avgLng = cell.Average(p => p.Lng);

            var cellCenter = GeoLocation.Create(avgLat, avgLng);
            var nearbyDrivers = idleDrivers.Count(d =>
            {
                var driverLoc = GeoLocation.Create(d.Latitude, d.Longitude);
                return cellCenter.DistanceKm(driverLoc) <= 3.0;
            });

            var ratio = nearbyDrivers > 0
                ? (double)orderCount / nearbyDrivers
                : orderCount * 2.0;

            if (ratio < 1.5) continue;

            var (level, bonus) = ratio switch
            {
                >= 5.0 => ("Surge", 40m),
                >= 3.0 => ("High", 20m),
                >= 2.0 => ("Moderate", 10m),
                _ => ("Low", 0m)
            };

            if (level == "Low") continue;

            zones.Add(new SurgeZoneResponse(
                Math.Round(avgLat, 4),
                Math.Round(avgLng, 4),
                FindNearestArea(avgLat, avgLng),
                orderCount,
                nearbyDrivers,
                Math.Round(ratio, 1),
                level,
                bonus));
        }

        return Ok(zones.OrderByDescending(z => z.DemandSupplyRatio).Take(10).ToList());
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

public sealed record SurgeZoneResponse(
    double Latitude,
    double Longitude,
    string AreaName,
    int PendingOrders,
    int ActiveDrivers,
    double DemandSupplyRatio,
    string Level,
    decimal SurgeBonus);
