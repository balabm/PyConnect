namespace PondyConnect.Domain.Enums;

/// <summary>
/// Lifecycle of a split payment pool (P2P cost-sharing for high-ticket items).
/// </summary>
public enum SplitPaymentStatus
{
    Active = 1,
    FullyPaid = 2,
    Cancelled = 3,
    Expired = 4
}
