namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Distributed mutual-exclusion primitive backed by Redis (SET NX EX + guarded
/// delete). A null return means the lease could not be acquired within
/// <paramref name="waitTimeout"/> — the caller must treat that as a busy
/// resource, never as success.
/// </summary>
public interface IDistributedLock
{
    /// <summary>
    /// Acquires a lease on <paramref name="resourceKey"/>, retrying for up to
    /// <paramref name="waitTimeout"/>. Returns a handle that owns the lease
    /// (released on dispose) or null when the timeout elapses first.
    /// </summary>
    Task<IDistributedLockHandle?> TryAcquireAsync(
        string resourceKey,
        TimeSpan leaseDuration,
        TimeSpan waitTimeout,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// A held distributed-lock lease. Disposing releases the key.
/// </summary>
public interface IDistributedLockHandle : IDisposable, IAsyncDisposable
{
    string ResourceKey { get; }
}