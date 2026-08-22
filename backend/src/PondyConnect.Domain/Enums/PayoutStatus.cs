namespace PondyConnect.Domain.Enums;

/// <summary>
/// Tracks the lifecycle of a payout to a vendor or driver.
/// </summary>
public enum PayoutStatus
{
    /// <summary>Payout request created, not yet sent to provider</summary>
    Pending = 1,

    /// <summary>Payout sent to RazorpayX, awaiting confirmation</summary>
    Processing = 2,

    /// <summary>Payout confirmed by bank, UTR received</summary>
    Completed = 3,

    /// <summary>Payout reversed/bounced (invalid account, frozen, etc.)</summary>
    Failed = 4,

    /// <summary>Payout cancelled before sending</summary>
    Cancelled = 5
}
