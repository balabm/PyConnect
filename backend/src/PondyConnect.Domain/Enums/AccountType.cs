namespace PondyConnect.Domain.Enums;

/// <summary>
/// Double-entry ledger account types. Every rupee that flows through
/// the system must balance across these accounts.
/// </summary>
public enum AccountType
{
    /// <summary>Asset: funds held by Razorpay gateway awaiting settlement</summary>
    RazorpayReceivable = 1,

    /// <summary>Liability: amount owed to a vendor/partner</summary>
    PartnerPayable = 2,

    /// <summary>Liability: amount owed to a captain/driver</summary>
    CaptainPayable = 3,

    /// <summary>Revenue: platform commission earned</summary>
    PlatformRevenue = 4,

    /// <summary>Liability: GST output tax collected on commission (18%)</summary>
    GstOutputPayable = 5,

    /// <summary>Asset/Liability: consumer wallet balance (promo + real)</summary>
    ConsumerWallet = 6,

    /// <summary>Asset: cash held in escrow pending payout</summary>
    EscrowHold = 7,

    /// <summary>Expense: refund issued to consumer</summary>
    RefundExpense = 8,

    /// <summary>Liability: TDS deducted from vendor payouts (194O - 0.1%)</summary>
    TdsPayable = 9
}
