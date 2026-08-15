namespace PondyConnect.Domain.Enums;

public enum CancelReason
{
    RiderChangedMind = 1,
    DriverNoShow = 2,
    DriverCancelled = 3,
    PickupTooFar = 4,
    RiderNoShow = 5,
    SystemTimeout = 6,
    Other = 7
}
