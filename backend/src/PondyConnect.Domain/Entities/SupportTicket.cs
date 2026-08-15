namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

public sealed class SupportTicket : BaseEntity
{
    public Guid UserId { get; private set; }

    public SupportTicketStatus Status { get; private set; } = SupportTicketStatus.Open;

    public TicketPriority Priority { get; private set; } = TicketPriority.Normal;

    public TicketSource Source { get; private set; } = TicketSource.InApp;

    public double? Latitude { get; private set; }

    public double? Longitude { get; private set; }

    public string? IssueCategory { get; private set; }

    public DateTimeOffset? ResolvedAt { get; private set; }

    public DateTimeOffset? AcknowledgedAt { get; private set; }

    private SupportTicket()
    {
    }

    public static SupportTicket Create(
        Guid userId,
        TicketPriority priority = TicketPriority.Normal,
        TicketSource source = TicketSource.InApp,
        double? latitude = null,
        double? longitude = null,
        string? issueCategory = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (latitude.HasValue && (latitude.Value < -90 || latitude.Value > 90))
            throw new ArgumentOutOfRangeException(nameof(latitude), "Latitude must be between -90 and 90.");
        if (longitude.HasValue && (longitude.Value < -180 || longitude.Value > 180))
            throw new ArgumentOutOfRangeException(nameof(longitude), "Longitude must be between -180 and 180.");

        return new SupportTicket
        {
            UserId = userId,
            Status = SupportTicketStatus.Open,
            Priority = priority,
            Source = source,
            Latitude = latitude,
            Longitude = longitude,
            IssueCategory = issueCategory
        };
    }

    public void Escalate()
    {
        Priority = TicketPriority.Critical;
        Status = SupportTicketStatus.Escalated;
        MarkUpdated();
    }

    public void MarkInProgress()
    {
        if (Status == SupportTicketStatus.Open)
        {
            Status = SupportTicketStatus.InProgress;
            MarkUpdated();
        }
    }

    public void Resolve()
    {
        Status = SupportTicketStatus.Resolved;
        ResolvedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Acknowledge()
    {
        AcknowledgedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}
