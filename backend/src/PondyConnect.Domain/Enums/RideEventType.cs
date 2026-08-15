namespace PondyConnect.Domain.Enums;

public enum RideEventType
{
    Created = 1,
    Dispatched = 2,
    DriverAssigned = 3,
    ArrivedAtPickup = 4,
    OtpVerified = 5,
    Started = 6,
    Completed = 7,
    Cancelled = 8,
    SosTriggered = 9,
    SosResolved = 10,
    RatingSubmitted = 11,
    DriverReassigned = 12,
    NoDriversAvailable = 13
}
