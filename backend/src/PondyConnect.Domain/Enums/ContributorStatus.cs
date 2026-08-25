namespace PondyConnect.Domain.Enums;

/// <summary>
/// Payment state of an individual contributor in a split payment pool.
/// </summary>
public enum ContributorStatus
{
    Pending = 1,
    Paid = 2,
    Refunded = 3
}
