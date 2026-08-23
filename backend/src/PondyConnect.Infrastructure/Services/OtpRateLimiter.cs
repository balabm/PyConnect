namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Caching.Distributed;
using PondyConnect.Application.Services;

/// <summary>
/// Fixed-window OTP rate limiter backed by the registered
/// <see cref="IDistributedCache"/> (Redis in production, in-memory in dev).
/// Each key tracks a request counter that resets at the start of every
/// 15-minute fixed window. The window boundary is derived from the current
/// UTC time so that the cache entry's absolute expiration aligns with the
/// next window start, providing natural cleanup.
/// </summary>
public sealed class OtpRateLimiter : IOtpRateLimiter
{
    private readonly IDistributedCache _cache;

    public TimeSpan Window => TimeSpan.FromMinutes(15);

    public int MaxRequests => 20;

    public OtpRateLimiter(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<bool> TryConsumeAsync(string key)
    {
        var now = DateTimeOffset.UtcNow;
        var windowStart = GetWindowStart(now);
        var windowEnd = windowStart + Window;
        var cacheKey = $"{key}:{windowStart:yyyyMMddHHmm}";

        var raw = await _cache.GetStringAsync(cacheKey);
        var currentCount = string.IsNullOrEmpty(raw) ? 0 : int.Parse(raw, System.Globalization.CultureInfo.InvariantCulture);

        if (currentCount >= MaxRequests)
            return false;

        currentCount++;

        var options = new DistributedCacheEntryOptions
        {
            AbsoluteExpiration = windowEnd,
        };

        await _cache.SetStringAsync(cacheKey, currentCount.ToString(System.Globalization.CultureInfo.InvariantCulture), options);
        return true;
    }

    /// <summary>
    /// Returns the start of the current fixed window (floored to the
    /// nearest <see cref="Window"/> boundary in UTC).
    /// </summary>
    private DateTimeOffset GetWindowStart(DateTimeOffset now)
    {
        var windowTicks = Window.Ticks;
        var flooredTicks = now.UtcTicks / windowTicks * windowTicks;
        return new DateTimeOffset(flooredTicks, TimeSpan.Zero);
    }
}
