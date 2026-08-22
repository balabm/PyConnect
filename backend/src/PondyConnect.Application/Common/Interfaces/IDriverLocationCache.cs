namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Read-only access to the in-memory driver location cache. Implemented by
/// <c>DriverLocationStore</c> in the API layer and injected into application
/// handlers that need to check driver GPS freshness (e.g. stale-GPS
/// cancellation fee waivers).
/// </summary>
public interface IDriverLocationCache
{
    /// <summary>
    /// Returns the UTC timestamp of the driver's last GPS ping, or
    /// <c>null</c> if the driver has no cached location entry.
    /// </summary>
    DateTimeOffset? GetLastPingTime(Guid driverId);

    /// <summary>
    /// Returns <c>true</c> if the driver's last GPS ping is older than the
    /// supplied <paramref name="threshold"/> (or the driver has no entry at
    /// all). This is used to waive cancellation fees when the captain's
    /// device has lost connectivity.
    /// </summary>
    bool IsStale(Guid driverId, TimeSpan threshold);
}
