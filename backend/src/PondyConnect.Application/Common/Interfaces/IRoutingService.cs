namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Provides road-based routing between two geographic points.
/// Used to validate client-submitted distance/duration and to compute
/// route geometry for trip tracking.
/// </summary>
public interface IRoutingService
{
    /// <summary>
    /// Calculates the road route between two coordinates.
    /// Returns null if routing fails or no route is found.
    /// </summary>
    Task<RouteInfo?> GetRouteAsync(
        double startLat, double startLng,
        double endLat, double endLng,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Road route information: distance, duration, and decoded polyline points.
/// </summary>
public sealed record RouteInfo(
    double DistanceKm,
    int DurationMin,
    IReadOnlyList<(double Lat, double Lng)> Points);
