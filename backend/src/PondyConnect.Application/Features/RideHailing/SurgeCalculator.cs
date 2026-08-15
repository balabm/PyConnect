namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Distributed;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using System.Text.Json;

/// <summary>
/// Calculates surge multiplier based on supply/demand ratio in a zone.
/// Capped at 1.5x. Caches result per zone for 2 minutes to avoid recalculating
/// on every request. Driver receives 100% of the surge portion.
/// </summary>
public sealed class SurgeCalculator
{
    private const double NormalRatio = 1.0;       // requests per driver
    private const double BusyRatio = 2.0;         // 2+ requests per driver → 1.2x
    private const double HighDemandRatio = 4.0;   // 4+ requests per driver → 1.5x

    private const decimal NormalMultiplier = 1.0m;
    private const decimal BusyMultiplier = 1.2m;
    private const decimal HighDemandMultiplier = 1.5m;

    private const int CacheSeconds = 120;
    private const int RecentRequestWindowMinutes = 5;
    private const double ZoneRadiusKm = 3.0;

    private readonly IApplicationDbContext _context;
    private readonly IDistributedCache _cache;

    public SurgeCalculator(IApplicationDbContext context, IDistributedCache cache)
    {
        _context = context;
        _cache = cache;
    }

    /// <summary>
    /// Calculate the surge multiplier for a pickup location and vehicle type.
    /// Returns (multiplier, reason). Multiplier is capped at 1.5x.
    /// </summary>
    public async Task<(decimal Multiplier, string? Reason)> CalculateSurgeAsync(
        GeoLocation pickup,
        VehicleType vehicleType,
        CancellationToken cancellationToken = default)
    {
        var cacheKey = $"surge:{pickup.Latitude:F3}:{pickup.Longitude:F3}:{vehicleType}";

        var cached = await _cache.GetStringAsync(cacheKey, cancellationToken);
        if (cached is not null)
        {
            var result = JsonSerializer.Deserialize<SurgeCacheEntry>(cached);
            if (result is not null)
                return (result.Multiplier, result.Reason);
        }

        var since = DateTimeOffset.UtcNow.AddMinutes(-RecentRequestWindowMinutes);

        // Count recent ride requests in zone (active demand)
        // SQLite cannot translate DateTimeOffset comparisons in Where clauses, so fetch all and filter on client
        var recentRequestsRaw = await _context.RideRequests
            .ToListAsync(cancellationToken);

        var requestCount = recentRequestsRaw
            .Where(r => r.RequestedAt >= since &&
                        r.VehicleType == vehicleType &&
                        r.Status != RideStatus.Cancelled &&
                        r.Status != RideStatus.Completed &&
                        r.PickupLocation.DistanceKm(pickup) <= ZoneRadiusKm)
            .Count();

        // Count available online drivers in zone (supply)
        var onlineDriversRaw = await _context.Drivers
            .Where(d => d.IsOnline && d.IsApproved && !d.IsOnRide)
            .ToListAsync(cancellationToken);

        var driverCount = onlineDriversRaw
            .Where(d => d.VehicleType == vehicleType)
            .Count(d => d.CurrentLocation.DistanceKm(pickup) <= ZoneRadiusKm);

        var (multiplier, reason) = CalculateFromRatio(requestCount, driverCount);

        // Cache the result
        var entry = new SurgeCacheEntry(multiplier, reason);
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = TimeSpan.FromSeconds(CacheSeconds)
        };
        await _cache.SetStringAsync(cacheKey, JsonSerializer.Serialize(entry), options, cancellationToken);

        return (multiplier, reason);
    }

    /// <summary>
    /// Pure function for calculating surge from a supply/demand ratio.
    /// Exposed for unit testing without database dependencies.
    /// </summary>
    public static (decimal Multiplier, string? Reason) CalculateFromRatio(int requestCount, int driverCount)
    {
        // No surge if no demand or plenty of supply
        if (requestCount == 0)
            return (NormalMultiplier, null);

        // Avoid division by zero — if no drivers, treat as high demand
        var ratio = driverCount == 0 ? HighDemandRatio : (double)requestCount / driverCount;

        if (ratio >= HighDemandRatio)
            return (HighDemandMultiplier, "High demand in your area — surge capped at 1.5x");

        if (ratio >= BusyRatio)
            return (BusyMultiplier, "Busy period — surge at 1.2x");

        return (NormalMultiplier, null);
    }

    private sealed record SurgeCacheEntry(decimal Multiplier, string? Reason);
}
