namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Idempotency journal for inbound provider webhooks (Razorpay). Each row
/// records a webhook event that has already been fully processed, so a
/// redelivery of the same <c>event_id</c> can be short-circuited to 200 OK
/// without re-charging or double-confirming an order.
/// </summary>
public sealed class ProcessedWebhook : BaseEntity
{
    /// <summary>
    /// The provider-assigned event identifier (e.g. Razorpay <c>evt_…</c>).
    /// Unique across the table — a duplicate insert violates the constraint
    /// and signals a replay.
    /// </summary>
    public string EventId { get; private set; } = string.Empty;

    /// <summary>
    /// The webhook event type (e.g. <c>payment.captured</c>,
    /// <c>order.paid</c>).
    /// </summary>
    public string EventType { get; private set; } = string.Empty;

    /// <summary>
    /// UTC timestamp at which the webhook was processed.
    /// </summary>
    public DateTimeOffset ProcessedAt { get; private set; }

    /// <summary>
    /// Optional raw JSON payload for audit/debugging.
    /// </summary>
    public string? Payload { get; private set; }

    private ProcessedWebhook()
    {
        // EF Core constructor.
    }

    public static ProcessedWebhook Create(
        string eventId,
        string eventType,
        string? payload = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(eventId);
        ArgumentException.ThrowIfNullOrWhiteSpace(eventType);

        return new ProcessedWebhook
        {
            EventId = eventId,
            EventType = eventType,
            ProcessedAt = DateTimeOffset.UtcNow,
            Payload = payload,
        };
    }
}
