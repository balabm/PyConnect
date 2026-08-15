namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

public sealed class AppEventLog : BaseEntity
{
    public Guid? UserId { get; private set; }

    public string SessionId { get; private set; } = string.Empty;

    public string EventName { get; private set; } = string.Empty;

    public string? EventPayload { get; private set; }

    private AppEventLog()
    {
    }

    public static AppEventLog Create(
        Guid? userId,
        string sessionId,
        string eventName,
        string? payloadJson = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(eventName);
        ArgumentException.ThrowIfNullOrWhiteSpace(sessionId);

        return new AppEventLog
        {
            UserId = userId,
            SessionId = sessionId,
            EventName = eventName,
            EventPayload = payloadJson,
        };
    }
}
