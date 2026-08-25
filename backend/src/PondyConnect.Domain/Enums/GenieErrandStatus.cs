namespace PondyConnect.Domain.Enums;

/// <summary>
/// Lifecycle of a Genie Engine custom errand request.
/// </summary>
public enum GenieErrandStatus
{
    Draft = 1,
    Posted = 2,
    Accepted = 3,
    InProgress = 4,
    Completed = 5,
    Cancelled = 6
}
