namespace PondyConnect.Infrastructure.Locking;

/// <summary>
/// Redis Lua scripts used by the distributed lock. The compare-and-delete
/// script guarantees a lock is only released by the process that holds it.
/// </summary>
internal static class Scripts
{
    public const string CompareAndDelete = """
        if redis.call('get', KEYS[1]) == ARGV[1] then
            return redis.call('del', KEYS[1])
        else
            return 0
        end
        """;
}