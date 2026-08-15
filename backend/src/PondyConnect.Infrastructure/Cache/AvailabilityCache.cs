namespace PondyConnect.Infrastructure.Cache;

using PondyConnect.Application.Common.Interfaces;

public sealed class AvailabilityCache : IAvailabilityCache
{
    private readonly RedisCacheService _cache;
    private const string OccupancyKeyPrefix = "venue:occupancy:";

    public AvailabilityCache(RedisCacheService cache)
    {
        _cache = cache;
    }

    public async Task<int?> GetVenueOccupancyAsync(Guid venueId, CancellationToken cancellationToken = default)
        => await _cache.GetAsync<int?>(OccupancyKey(venueId), cancellationToken);

    public Task SetVenueOccupancyAsync(Guid venueId, int occupancy, TimeSpan? expiry = null, CancellationToken cancellationToken = default)
        => _cache.SetAsync(OccupancyKey(venueId), occupancy, expiry ?? TimeSpan.FromMinutes(2), cancellationToken);

    public Task RemoveVenueOccupancyAsync(Guid venueId, CancellationToken cancellationToken = default)
        => _cache.RemoveAsync(OccupancyKey(venueId), cancellationToken);

    public async Task<IReadOnlyDictionary<Guid, int>> GetOccupanciesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken cancellationToken = default)
    {
        var result = new Dictionary<Guid, int>();
        foreach (var id in venueIds)
        {
            var occupancy = await _cache.GetAsync<int?>(OccupancyKey(id), cancellationToken);
            if (occupancy is not null)
                result[id] = occupancy.Value;
        }
        return result;
    }

    private static string OccupancyKey(Guid venueId) => $"{OccupancyKeyPrefix}{venueId}";
}