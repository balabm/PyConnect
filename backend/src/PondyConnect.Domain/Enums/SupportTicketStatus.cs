namespace PondyConnect.Domain.Enums;

public enum SupportTicketStatus
{
    Open = 1,
    AutoResolved = 2,
    UnderReview = 3,
    Resolved = 4,
    Rejected = 5,

    // Legacy SOS/AI support statuses retained for backward compatibility.
    InProgress = 6,
    Escalated = 7
}
