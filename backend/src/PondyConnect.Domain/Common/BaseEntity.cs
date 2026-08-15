namespace PondyConnect.Domain.Common;

public abstract class BaseEntity
{
    public Guid Id { get; private set; } = Guid.NewGuid();

    /// <summary>
    /// Assigns an explicit identity, used only by the data initializer for
    /// deterministic seed records (e.g. "Fuoco Pizzeria" as vendor #1).
    /// </summary>
    protected void SetExplicitId(Guid id) => Id = id;

    public DateTimeOffset CreatedAt { get; private set; } = DateTimeOffset.UtcNow;

    public DateTimeOffset? UpdatedAt { get; private set; }

    public void MarkUpdated() => UpdatedAt = DateTimeOffset.UtcNow;

    protected static bool IsValidOrFutureTimestamp(DateTimeOffset value)
        => value >= DateTimeOffset.UnixEpoch;
}