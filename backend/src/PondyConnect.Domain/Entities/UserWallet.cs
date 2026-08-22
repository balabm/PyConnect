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

    /// <summary>
    /// PY Coins loyalty balance. 1 PY Coin = ₹1 when redeeming against
    /// platform fees. Earned at 1 coin per ₹100 spent on orders/rides.
    /// </summary>
    public int PyCoins { get; private set; }

    private UserWallet()
    {
    }

    public static UserWallet Create(Guid userId, decimal promoBalance = 0m, decimal realBalance = 0m, int pyCoins = 0)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(promoBalance, nameof(promoBalance));
        ArgumentOutOfRangeException.ThrowIfNegative(realBalance, nameof(realBalance));
        ArgumentOutOfRangeException.ThrowIfNegative(pyCoins, nameof(pyCoins));

        return new UserWallet
        {
            UserId = userId,
            PromoBalance = promoBalance,
            RealBalance = realBalance,
            PyCoins = pyCoins
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

    /// <summary>
    /// Credits PY Coins earned from a completed order or ride.
    /// 1 PY Coin per ₹100 spent.
    /// </summary>
    public void CreditCoins(int coins)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(coins, nameof(coins));
        PyCoins += coins;
        MarkUpdated();
    }

    /// <summary>
    /// Debits PY Coins when the user redeems them against platform
    /// fees at checkout. 1 PY Coin = ₹1 discount.
    /// </summary>
    public void DebitCoins(int coins)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(coins, nameof(coins));
        if (coins > PyCoins)
            throw new InvalidOperationException("Insufficient PY Coins.");
        PyCoins -= coins;
        MarkUpdated();
    }
}
