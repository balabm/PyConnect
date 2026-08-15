namespace PondyConnect.Domain.Enums;

public enum RideStatus
{
    Requested = 1,
    Accepted = 2,
    EnRoute = 3,
    Completed = 4,
    Cancelled = 5,
    Searching = 6,
    DriverAssigned = 7,
    ArrivedAtPickup = 8,
    DriverCancelled = 9,
    NoDriversAvailable = 10
}
