namespace PondyConnect.Application.Services;

/// <summary>
/// Distributed-cache backed idempotency guard. Prevents duplicate checkout
/// charges by returning a cached response for a previously seen key.
/// </summary>
public interface IIdempotencyService
{
    /// <summary>
    /// Returns the cached response for the idempotency key, or <c>default</c>
    /// if no value has been stored.
    /// </summary>
    Task<T?> GetAsync<T>(string key, CancellationToken ct);

    /// <summary>
    /// Caches the checkout response for the specified idempotency key and TTL.
    /// </summary>
    Task SetAsync<T>(string key, T value, TimeSpan expiry, CancellationToken ct);
}
