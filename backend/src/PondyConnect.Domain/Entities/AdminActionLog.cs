namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Audit log of every powerful admin action in the super app.
/// </summary>
public sealed class AdminActionLog : BaseEntity
{
    public Guid AdminUserId { get; private set; }

    public string ActionType { get; private set; } = string.Empty;

    public string? EntityType { get; private set; }

    public Guid? EntityId { get; private set; }

    public string? Payload { get; private set; }

    public string? IpAddress { get; private set; }

    private AdminActionLog()
    {
    }

    public static AdminActionLog Create(
        Guid adminUserId,
        string actionType,
        string? entityType = null,
        Guid? entityId = null,
        string? payload = null,
        string? ipAddress = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(actionType);

        return new AdminActionLog
        {
            AdminUserId = adminUserId,
            ActionType = actionType,
            EntityType = entityType,
            EntityId = entityId,
            Payload = payload,
            IpAddress = ipAddress,
        };
    }
}
