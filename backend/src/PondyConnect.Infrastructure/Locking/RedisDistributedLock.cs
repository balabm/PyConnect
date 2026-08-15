namespace PondyConnect.Infrastructure.Locking;

using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Redis-backed distributed lock using the atomic SET key value NX PX EX
/// primitive from StackExchange.Redis, released only when the caller owns the
/// matching token (compare-and-delete). Guarantees mutual exclusion across
/// multiple API instances during flash-sale venue bookings.
/// </summary>
public sealed class RedisDistributedLock : IDistributedLock
{
    private readonly StackExchange.Redis.IDatabase _db;
    private static readonly TimeSpan s_retryInterval = TimeSpan.FromMilliseconds(25);

    public RedisDistributedLock(StackExchange.Redis.IConnectionMultiplexer multiplexer)
    {
        _db = multiplexer.GetDatabase();
    }

    public async Task<IDistributedLockHandle?> TryAcquireAsync(
        string resourceKey,
        TimeSpan leaseDuration,
        TimeSpan waitTimeout,
        CancellationToken cancellationToken = default)
    {
        var token = Guid.NewGuid().ToString("N");
        var deadline = DateTimeOffset.UtcNow + waitTimeout;

        while (!cancellationToken.IsCancellationRequested)
        {
            var acquired = await _db.StringSetAsync(
                LockKey(resourceKey), token, leaseDuration, StackExchange.Redis.When.NotExists)
                .ConfigureAwait(false);

            if (acquired)
                return new LockHandle(resourceKey, token, this);

            if (DateTimeOffset.UtcNow >= deadline)
                return null;

            await Task.Delay(s_retryInterval, cancellationToken).ConfigureAwait(false);
        }

        return null;
    }

    private async Task ReleaseAsync(string resourceKey, string token)
    {
        var key = LockKey(resourceKey);

        // Atomic compare-and-delete: only delete if our token still owns the key.
        var script = Scripts.CompareAndDelete;
        await _db.ScriptEvaluateAsync(
            script,
            new StackExchange.Redis.RedisKey[] { key },
            new StackExchange.Redis.RedisValue[] { token }).ConfigureAwait(false);
    }

    private static string LockKey(string resourceKey) => $"lock:{resourceKey}";

    private sealed class LockHandle : IDistributedLockHandle
    {
        private readonly string _token;
        private readonly RedisDistributedLock _owner;
        private int _released;

        public LockHandle(string resourceKey, string token, RedisDistributedLock owner)
        {
            ResourceKey = resourceKey;
            _token = token;
            _owner = owner;
        }

        public string ResourceKey { get; }

        public void Dispose() => Release();

        public ValueTask DisposeAsync()
        {
            Release();
            return ValueTask.CompletedTask;
        }

        private void Release()
        {
            if (Interlocked.Exchange(ref _released, 1) == 0)
                _owner.ReleaseAsync(ResourceKey, _token).GetAwaiter().GetResult();
        }
    }
}