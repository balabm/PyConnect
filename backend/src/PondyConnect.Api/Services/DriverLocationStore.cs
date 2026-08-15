namespace PondyConnect.Api.Services;

using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// In-memory store for driver live locations. Singleton — survives for the
/// lifetime of the API process. Drivers update via SignalR (DriverHub) every
/// 3-5 seconds while online. Stale entries (>60s) are considered offline.
/// </summary>
public sealed class DriverLocationStore
{
    private readonly Dictionary<Guid, DriverLocationEntry> _entries = new();
    private readonly object _lock = new();
    private readonly TimeSpan _staleThreshold = TimeSpan.FromSeconds(60);

    public void Update(Guid driverId, double latitude, double longitude, double? heading = null)
    {
        lock (_lock)
        {
            _entries[driverId] = new DriverLocationEntry(
                driverId,
                latitude,
                longitude,
                heading,
                DateTimeOffset.UtcNow,
                IsOnline: true,
                IsOnRide: _entries.TryGetValue(driverId, out var existing) && existing.IsOnRide,
                CurrentRideId: _entries.TryGetValue(driverId, out var ex2) ? ex2.CurrentRideId : null,
                VehicleType: _entries.TryGetValue(driverId, out var ex3) ? ex3.VehicleType : null,
                Rating: _entries.TryGetValue(driverId, out var ex4) ? ex4.Rating : 5.0,
                AcceptanceRate: _entries.TryGetValue(driverId, out var ex5) ? ex5.AcceptanceRate : 1.0);
        }
    }

    public void RegisterDriver(Guid driverId, VehicleType vehicleType, double rating = 5.0, double acceptanceRate = 1.0)
    {
        lock (_lock)
        {
            if (_entries.TryGetValue(driverId, out var existing))
            {
                _entries[driverId] = existing with { VehicleType = vehicleType, Rating = rating, AcceptanceRate = acceptanceRate };
            }
            else
            {
                _entries[driverId] = new DriverLocationEntry(
                    driverId, 0, 0, null, DateTimeOffset.UtcNow,
                    IsOnline: false, IsOnRide: false, CurrentRideId: null,
                    VehicleType: vehicleType, Rating: rating, AcceptanceRate: acceptanceRate);
            }
        }
    }

    public void SetOnline(Guid driverId, bool isOnline)
    {
        lock (_lock)
        {
            if (_entries.TryGetValue(driverId, out var existing))
            {
                _entries[driverId] = existing with { IsOnline = isOnline, UpdatedAt = DateTimeOffset.UtcNow };
            }
        }
    }

    public void SetOnRide(Guid driverId, Guid? rideId)
    {
        lock (_lock)
        {
            if (_entries.TryGetValue(driverId, out var existing))
            {
                _entries[driverId] = existing with { IsOnRide = rideId != null, CurrentRideId = rideId };
            }
        }
    }

    public DriverLocationEntry? Get(Guid driverId)
    {
        lock (_lock)
        {
            return _entries.TryGetValue(driverId, out var entry) ? entry : null;
        }
    }

    public void Remove(Guid driverId)
    {
        lock (_lock)
        {
            _entries.Remove(driverId);
        }
    }

    /// <summary>
    /// Get nearby drivers sorted by distance. Filters by online, not-on-ride,
    /// vehicle type, and freshness (not stale). Uses bounding-box pre-filter
    /// then Haversine for accuracy.
    /// </summary>
    public IReadOnlyList<DriverDistanceResult> GetNearby(
        GeoLocation center,
        double radiusKm,
        VehicleType? vehicleTypeFilter = null,
        int maxCount = 5)
    {
        List<DriverDistanceResult> results = new();
        var now = DateTimeOffset.UtcNow;

        // Bounding box pre-filter (approximate)
        var latDelta = radiusKm / 111.0;
        var lngDelta = radiusKm / (111.0 * Math.Cos(center.Latitude * Math.PI / 180.0));

        lock (_lock)
        {
            foreach (var entry in _entries.Values)
            {
                // Skip stale entries
                if (now - entry.UpdatedAt > _staleThreshold)
                    continue;

                // Skip offline or on-ride drivers
                if (!entry.IsOnline || entry.IsOnRide)
                    continue;

                // Vehicle type filter
                if (vehicleTypeFilter.HasValue && entry.VehicleType != vehicleTypeFilter.Value)
                    continue;

                // Bounding box check
                if (Math.Abs(entry.Latitude - center.Latitude) > latDelta ||
                    Math.Abs(entry.Longitude - center.Longitude) > lngDelta)
                    continue;

                // Precise Haversine distance
                var driverLoc = GeoLocation.Create(entry.Latitude, entry.Longitude);
                var distance = center.DistanceKm(driverLoc);

                if (distance <= radiusKm)
                {
                    results.Add(new DriverDistanceResult(
                        entry.DriverId,
                        distance,
                        entry.Rating,
                        entry.AcceptanceRate,
                        entry.VehicleType));
                }
            }
        }

        return results
            .OrderBy(r => r.DistanceKm)
            .Take(maxCount)
            .ToList();
    }

    /// <summary>
    /// Get all online, non-stale drivers (for nearby-drivers endpoint without DB load).
    /// </summary>
    public IReadOnlyList<DriverLocationEntry> GetOnlineDrivers()
    {
        var now = DateTimeOffset.UtcNow;
        lock (_lock)
        {
            return _entries.Values
                .Where(e => e.IsOnline && (now - e.UpdatedAt) <= _staleThreshold)
                .ToList();
        }
    }
}

public sealed record DriverLocationEntry(
    Guid DriverId,
    double Latitude,
    double Longitude,
    double? Heading,
    DateTimeOffset UpdatedAt,
    bool IsOnline,
    bool IsOnRide,
    Guid? CurrentRideId,
    VehicleType? VehicleType,
    double Rating,
    double AcceptanceRate);

public sealed record DriverDistanceResult(
    Guid DriverId,
    double DistanceKm,
    double Rating,
    double AcceptanceRate,
    VehicleType? VehicleType);
