namespace PondyConnect.Domain.Enums;

public enum PaymentProvider
{
    None = 0,
    Razorpay = 1,
    Stripe = 2,
    UpiIntent = 3
}

public enum PaymentMethod
{
    Unknown = 0,
    Cash = 1,
    Upi = 2,
    Card = 3,
    NetBanking = 4,
    Wallet = 5
}