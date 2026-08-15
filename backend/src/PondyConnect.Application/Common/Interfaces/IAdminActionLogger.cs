namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Writes an audit record for every sensitive admin action.
/// </summary>
public interface IAdminActionLogger
{
    Task LogAsync(
        string actionType,
        string? entityType = null,
        Guid? entityId = null,
        object? payload = null,
        CancellationToken cancellationToken = default);
}
