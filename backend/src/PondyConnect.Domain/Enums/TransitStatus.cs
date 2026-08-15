namespace PondyConnect.Domain.Enums;

public enum TransitStatus
{
    Requested = 1,
    Assigned = 2,
    EnRoute = 3,
    Arrived = 4,
    Completed = 5,
    Cancelled = 6
}