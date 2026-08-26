namespace PondyConnect.Domain.Enums;

/// <summary>
/// Types of consumer wallet transactions.
/// </summary>
public enum UserWalletTransactionType
{
    /// <summary>Money added via Razorpay top-up.</summary>
    TopUp = 0,

    /// <summary>Promo credit granted (referral, waitlist, campaign).</summary>
    PromoCredit = 1,

    /// <summary>Spent on a food order.</summary>
    FoodOrderPayment = 2,

    /// <summary>Spent on a ride.</summary>
    RidePayment = 3,

    /// <summary>Spent on equipment rental.</summary>
    EquipmentRentalPayment = 4,

    /// <summary>Spent on an event ticket.</summary>
    EventTicketPayment = 5,

    /// <summary>Refund for a cancelled order or ride.</summary>
    Refund = 6,

    /// <summary>PY Coins redeemed for platform fees.</summary>
    CoinRedemption = 7,

    /// <summary>Cashback earned from an order.</summary>
    Cashback = 8,
}
