namespace PondyConnect.Infrastructure.Services;

using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Caching.Distributed;
using PondyConnect.Application.Services;

/// <summary>
/// Redis-or-memory backed idempotency cache. Serializes checkout responses as
/// JSON with a 24-hour TTL so retries return the original result.
/// </summary>
public sealed class IdempotencyService : IIdempotencyService
{
    private const string KeyPrefix = "idempotency:";
    private readonly IDistributedCache _cache;

    public IdempotencyService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<T?> GetAsync<T>(string key, CancellationToken ct)
    {
        var data = await _cache.GetAsync(FormatKey(key), ct);
        if (data is null || data.Length == 0)
            return default;

        var json = Encoding.UTF8.GetString(data);
        return JsonSerializer.Deserialize<T>(json);
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan expiry, CancellationToken ct)
    {
        var json = JsonSerializer.Serialize(value);
        var data = Encoding.UTF8.GetBytes(json);
        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpirationRelativeToNow = expiry
        };

        await _cache.SetAsync(FormatKey(key), data, options, ct);
    }

    private static string FormatKey(string key)
    {
        if (key.StartsWith(KeyPrefix, StringComparison.Ordinal))
            return key;
        return KeyPrefix + key;
    }
}
