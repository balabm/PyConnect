namespace PondyConnect.Application.Features.Admin;

using Microsoft.Extensions.Caching.Distributed;
using System.Text.Json;

/// <summary>
/// Admin-controlled feature toggles stored in Redis (with in-memory
/// fallback). These "kill switches" allow the Admin to gracefully
/// degrade the app during 3rd-party API outages:
///
/// - IsRazorpayActive: when false, hide UPI/Card payment options and
///   force Cash on Delivery.
/// - IsGoogleMapsActive: when false, fall back to a static status list
///   instead of a live map widget.
/// - IsFoodDeliveryActive: when false, disable food ordering entirely.
///
/// The config is cached in Redis for 1 hour and falls back to a
/// static in-memory dictionary when Redis is unavailable.
/// </summary>
public sealed class SystemConfigService
{
    private readonly IDistributedCache _cache;
    private static readonly TimeSpan CacheExpiry = TimeSpan.FromHours(1);
    private const string CacheKey = "system:config";

    /// <summary>
    /// In-memory fallback used when Redis is not configured.
    /// </summary>
    private static readonly Dictionary<string, bool> s_inMemoryConfig = new()
    {
        ["IsRazorpayActive"] = true,
        ["IsGoogleMapsActive"] = true,
        ["IsFoodDeliveryActive"] = true,
        ["IsRideHailingActive"] = true,
        ["IsStaysActive"] = true,
        ["IsLuggageCloakActive"] = true,
        ["IsScooterRentalActive"] = true,
        ["IsNightlifeActive"] = true,
    };

    private static readonly object s_lock = new();

    public SystemConfigService(IDistributedCache cache)
    {
        _cache = cache;
    }

    /// <summary>
    /// Returns all feature toggles. Tries Redis first, falls back to
    /// in-memory config.
    /// </summary>
    public async Task<Dictionary<string, bool>> GetAllAsync(CancellationToken ct = default)
    {
        try
        {
            var bytes = await _cache.GetAsync(CacheKey, ct);
            if (bytes is not null)
            {
                var json = System.Text.Encoding.UTF8.GetString(bytes);
                var result = JsonSerializer.Deserialize<Dictionary<string, bool>>(json);
                if (result is not null)
                    return MergeWithDefaults(result);
            }
        }
        catch
        {
            // Redis unavailable — fall back to in-memory
        }

        lock (s_lock)
        {
            return new Dictionary<string, bool>(s_inMemoryConfig);
        }
    }

    /// <summary>
    /// Returns a single feature toggle. Returns true (active) if the
    /// key is not found, defaulting to "safe" behavior.
    /// </summary>
    public async Task<bool> GetAsync(string key, CancellationToken ct = default)
    {
        var all = await GetAllAsync(ct);
        return all.GetValueOrDefault(key, true);
    }

    /// <summary>
    /// Sets a feature toggle. Updates both Redis and the in-memory
    /// fallback.
    /// </summary>
    public async Task SetAsync(string key, bool value, CancellationToken ct = default)
    {
        var all = await GetAllAsync(ct);
        all[key] = value;

        // Update in-memory fallback
        lock (s_lock)
        {
            s_inMemoryConfig[key] = value;
        }

        // Update Redis
        try
        {
            var json = JsonSerializer.Serialize(all);
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            await _cache.SetAsync(CacheKey, bytes, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = CacheExpiry
            }, ct);
        }
        catch
        {
            // Redis unavailable — in-memory fallback is already updated
        }
    }

    /// <summary>
    /// Resets all toggles to their default (active) state.
    /// </summary>
    public async Task ResetAllAsync(CancellationToken ct = default)
    {
        var defaults = new Dictionary<string, bool>
        {
            ["IsRazorpayActive"] = true,
            ["IsGoogleMapsActive"] = true,
            ["IsFoodDeliveryActive"] = true,
            ["IsRideHailingActive"] = true,
            ["IsStaysActive"] = true,
            ["IsLuggageCloakActive"] = true,
            ["IsScooterRentalActive"] = true,
            ["IsNightlifeActive"] = true,
        };

        lock (s_lock)
        {
            foreach (var kv in defaults)
                s_inMemoryConfig[kv.Key] = kv.Value;
        }

        try
        {
            var json = JsonSerializer.Serialize(defaults);
            var bytes = System.Text.Encoding.UTF8.GetBytes(json);
            await _cache.SetAsync(CacheKey, bytes, new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = CacheExpiry
            }, ct);
        }
        catch
        {
            // Redis unavailable — in-memory fallback is already updated
        }
    }

    private static Dictionary<string, bool> MergeWithDefaults(Dictionary<string, bool> config)
    {
        var result = new Dictionary<string, bool>
        {
            ["IsRazorpayActive"] = true,
            ["IsGoogleMapsActive"] = true,
            ["IsFoodDeliveryActive"] = true,
            ["IsRideHailingActive"] = true,
            ["IsStaysActive"] = true,
            ["IsLuggageCloakActive"] = true,
            ["IsScooterRentalActive"] = true,
            ["IsNightlifeActive"] = true,
        };

        foreach (var kv in config)
            result[kv.Key] = kv.Value;

        return result;
    }
}
