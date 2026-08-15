namespace PondyConnect.Domain.Enums;

public enum DispatchTaskStatus
{
    Available = 1,
    Assigned = 2,
    InProgress = 3,
    Completed = 4,
    Cancelled = 5,
    // Food/essentials delivery intermediate phases (persisted for resume).
    ArrivedAtStore = 6,
    OutForDelivery = 7
}
