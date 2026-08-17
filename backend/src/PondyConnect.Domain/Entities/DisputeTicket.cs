namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A consumer-raised support or dispute ticket for orders, payments, and
/// service issues. Kept separate from the SOS/AI <see cref="SupportTicket"/>
/// flow to avoid collision while the automated resolution rules run.
/// </summary>
public sealed class DisputeTicket : BaseEntity
{
    public string UserId { get; private set; } = string.Empty;

    public Guid? OrderId { get; private set; }

    public string? OrderType { get; private set; }

    public SupportTicketCategory Category { get; private set; }

    public string Subject { get; private set; } = string.Empty;

    public string Description { get; private set; } = string.Empty;

    public string? PhotoUrl { get; private set; }

    public SupportTicketStatus Status { get; private set; } = SupportTicketStatus.Open;

    public decimal? ResolutionAmount { get; private set; }

    public string? ResolutionNote { get; private set; }

    public DateTimeOffset? ResolvedAt { get; private set; }

    private DisputeTicket()
    {
    }

    public static DisputeTicket Create(
        string userId,
        SupportTicketCategory category,
        string subject,
        string description,
        Guid? orderId = null,
        string? orderType = null,
        string? photoUrl = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(userId);
        ArgumentException.ThrowIfNullOrWhiteSpace(subject);
        ArgumentException.ThrowIfNullOrWhiteSpace(description);

        return new DisputeTicket
        {
            UserId = userId,
            Category = category,
            Subject = subject,
            Description = description,
            OrderId = orderId,
            OrderType = orderType,
            PhotoUrl = photoUrl,
            Status = SupportTicketStatus.Open
        };
    }

    public void ApplyResolution(SupportTicketStatus newStatus, decimal? amount, string? note)
    {
        Status = newStatus;
        ResolutionAmount = amount;
        ResolutionNote = note;

        if (newStatus is SupportTicketStatus.Resolved or SupportTicketStatus.AutoResolved)
        {
            ResolvedAt = DateTimeOffset.UtcNow;
        }

        MarkUpdated();
    }
}
