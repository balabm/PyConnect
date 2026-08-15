namespace PondyConnect.Application.Features.Wallet;

/// <summary>
/// Enforces the promo credit rule: promo balance can only cover up to 20%
/// of any transaction total. Provides calculation and debit helpers.
/// </summary>
public static class PromoCreditService
{
    public const decimal PromoCoverageCapPercent = 0.20m;
    public const decimal WaitlistSignupBonus = 500m;

    /// <summary>
    /// Returns the maximum promo credit applicable for a given transaction total,
    /// capped at 20% of the total and limited by the user's available promo balance.
    /// </summary>
    public static decimal CalculateMaxApplicable(decimal transactionTotal, decimal promoBalance)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(transactionTotal, nameof(transactionTotal));
        ArgumentOutOfRangeException.ThrowIfNegative(promoBalance, nameof(promoBalance));

        var cap = transactionTotal * PromoCoverageCapPercent;
        return Math.Min(cap, promoBalance);
    }

    /// <summary>
    /// Splits a transaction total into promo portion and out-of-pocket portion.
    /// </summary>
    public static PromoSplitResult SplitPayment(decimal transactionTotal, decimal promoBalance)
    {
        var promoPortion = CalculateMaxApplicable(transactionTotal, promoBalance);
        var outOfPocket = transactionTotal - promoPortion;
        return new PromoSplitResult(promoPortion, outOfPocket);
    }
}

public sealed record PromoSplitResult(decimal PromoPortion, decimal OutOfPocketPortion);
