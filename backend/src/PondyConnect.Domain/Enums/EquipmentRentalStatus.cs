namespace PondyConnect.Domain.Enums;

/// <summary>
/// Lifecycle of an equipment rental booking tracked through the
/// Partner Kanban board (To Deliver -> Active in Field -> Awaiting Return -> Returned).
/// </summary>
public enum EquipmentRentalStatus
{
    Reserved = 1,
    Delivered = 2,
    ActiveInField = 3,
    AwaitingReturn = 4,
    Returned = 5,
    Cancelled = 6
}
