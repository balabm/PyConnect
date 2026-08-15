namespace PondyConnect.Infrastructure.Locking;

using System.Collections.Concurrent;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// In-process replacement for the Redis lock when no Redis connection string
/// is configured (local development and tests). Provides the same mutual
/// exclusion semantics within a single process, with lease expiry respected
/// so a crashed owner cannot block everyone forever.
/// </summary>
public sealed class InMemoryDistributedLock : IDistributedLock
{
    private readonly ConcurrentDictionary<string, LockEntry> _entries = new(StringComparer.Ordinal);

    public async Task<IDistributedLockHandle?> TryAcquireAsync(
        string resourceKey,
        TimeSpan leaseDuration,
        TimeSpan waitTimeout,
        CancellationToken cancellationToken = default)
    {
        var deadline = Environment.TickCount64 + (long)waitTimeout.TotalMilliseconds;

        while (!cancellationToken.IsCancellationRequested)
        {
            var entry = _entries.GetOrAdd(resourceKey, _ => new LockEntry());

            var token = entry.TryClaim(leaseDuration);
            if (token is not null)
                return new LockHandle(this, resourceKey, token.Value);

            if (Environment.TickCount64 >= deadline)
                return null;

            await Task.Delay(20, cancellationToken).ConfigureAwait(false);
        }

        return null;
    }

    internal void Release(string resourceKey, Guid token)
    {
        if (_entries.TryGetValue(resourceKey, out var entry))
            entry.ReleaseOwnedBy(token);
    }

    private sealed class LockEntry
    {
        private readonly object _gate = new();
        private Guid _owner;
        private DateTimeOffset _expiresAt = DateTimeOffset.MinValue;

        public Guid? TryClaim(TimeSpan leaseDuration)
        {
            lock (_gate)
            {
                if (DateTimeOffset.UtcNow < _expiresAt)
                    return null;

                var token = Guid.NewGuid();
                _owner = token;
                _expiresAt = DateTimeOffset.UtcNow + leaseDuration;
                return token;
            }
        }

        public void ReleaseOwnedBy(Guid token)
        {
            lock (_gate)
            {
                if (_owner == token)
                {
                    _owner = Guid.Empty;
                    _expiresAt = DateTimeOffset.MinValue;
                }
            }
        }
    }

    private sealed class LockHandle : IDistributedLockHandle
    {
        private readonly InMemoryDistributedLock _owner;
        private readonly Guid _token;
        private int _released;

        public LockHandle(InMemoryDistributedLock owner, string resourceKey, Guid token)
        {
            _owner = owner;
            ResourceKey = resourceKey;
            _token = token;
        }

        public string ResourceKey { get; }

        public void Dispose() => ReleaseOnce();

        public ValueTask DisposeAsync()
        {
            ReleaseOnce();
            return ValueTask.CompletedTask;
        }

        private void ReleaseOnce()
        {
            if (Interlocked.Exchange(ref _released, 1) == 0)
                _owner.Release(ResourceKey, _token);
        }
    }
}