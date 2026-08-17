namespace PondyConnect.Domain.Enums;

/// <summary>
/// Lifecycle state of a driver's wallet withdrawal request.
/// </summary>
public enum DriverWithdrawalStatus
{
    Pending = 1,
    Approved = 2,
    Rejected = 3,
    Processed = 4
}
