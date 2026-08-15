namespace PondyConnect.Application.Common.Interfaces;

using PondyConnect.Domain.Enums;

/// <summary>
/// Cached live state: venue vibe-check occupancy and transit GPS snapshots.
/// Redis is the backing store so capacity reads never hit Postgres.
/// </summary>
public interface IAvailabilityCache
{
    Task<int?> GetVenueOccupancyAsync(Guid venueId, CancellationToken cancellationToken = default);

    Task SetVenueOccupancyAsync(Guid venueId, int occupancy, TimeSpan? expiry = null, CancellationToken cancellationToken = default);

    Task RemoveVenueOccupancyAsync(Guid venueId, CancellationToken cancellationToken = default);

    Task<IReadOnlyDictionary<Guid, int>> GetOccupanciesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken cancellationToken = default);
}