namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Per-user wallet tracking promo and real balances. Promo credits are
/// granted from waitlist conversion (₹500) and can cover up to 20% of any
/// transaction total. Real balance holds topped-up funds with no cap.
/// </summary>
public sealed class UserWallet : BaseEntity
{
    public Guid UserId { get; private set; }

    public decimal PromoBalance { get; private set; }

    public decimal RealBalance { get; private set; }

    private UserWallet()
    {
    }

    public static UserWallet Create(Guid userId, decimal promoBalance = 0m, decimal realBalance = 0m)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(promoBalance, nameof(promoBalance));
        ArgumentOutOfRangeException.ThrowIfNegative(realBalance, nameof(realBalance));

        return new UserWallet
        {
            UserId = userId,
            PromoBalance = promoBalance,
            RealBalance = realBalance
        };
    }

    public void CreditPromo(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        PromoBalance += amount;
        MarkUpdated();
    }

    public void DebitPromo(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        if (amount > PromoBalance)
            throw new InvalidOperationException("Insufficient promo balance.");
        PromoBalance -= amount;
        MarkUpdated();
    }

    public void CreditReal(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        RealBalance += amount;
        MarkUpdated();
    }

    public void DebitReal(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        if (amount > RealBalance)
            throw new InvalidOperationException("Insufficient real balance.");
        RealBalance -= amount;
        MarkUpdated();
    }
}
