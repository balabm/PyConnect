namespace PondyConnect.Application.Features.Wallet;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Domain.Entities;

/// <summary>
/// Loyalty engine that accumulates PY Coins after every successful
/// order or ride completion. 1 PY Coin is earned per ₹100 spent.
/// Sends an immediate FCM push notification to the consumer:
/// "You earned 5 PY Coins from your last trip! Your total balance
/// is now 45 Coins."
/// </summary>
public sealed class LoyaltyService
{
    private readonly IApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<LoyaltyService> _logger;

    /// <summary>
    /// The earning rate: 1 PY Coin per ₹100 spent.
    /// </summary>
    private const decimal CoinsPerRupee = 1m / 100m;

    public LoyaltyService(IApplicationDbContext context, INotificationService notifications, ILogger<LoyaltyService> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    /// <summary>
    /// Awards PY Coins for a completed order or ride. Called after
    /// successful completion (delivery, ride completion, etc.).
    /// </summary>
    /// <param name="userId">The consumer's user ID.</param>
    /// <param name="amountSpent">The total amount spent (subtotal for food, fare for rides).</param>
    /// <param name="sourceType">"trip", "order", etc. — used in the notification text.</param>
    /// <param name="ct">Cancellation token.</param>
    /// <returns>The number of coins awarded.</returns>
    public async Task<int> AwardCoinsAsync(
        Guid userId,
        decimal amountSpent,
        string sourceType,
        CancellationToken ct = default)
    {
        if (amountSpent <= 0)
            return 0;

        // Calculate coins: 1 coin per ₹100 spent (rounded down)
        var coins = (int)(amountSpent * CoinsPerRupee);
        if (coins <= 0)
            return 0;

        // Get or create the user's wallet
        var wallet = await _context.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        if (wallet is null)
        {
            wallet = UserWallet.Create(userId);
            _context.UserWallets.Add(wallet);
        }

        var previousBalance = wallet.PyCoins;
        wallet.CreditCoins(coins);
        await _context.SaveChangesAsync(ct);

        // Send FCM push notification
        var sourceLabel = sourceType.ToLowerInvariant() switch
        {
            "trip" or "ride" => "trip",
            "order" or "food" => "order",
            "homestay" or "stay" => "booking",
            _ => "purchase"
        };

        await _notifications.SendTargetedPushAsync(
            userId,
            "PY Coins Earned!",
            $"You earned {coins} PY Coins from your last {sourceLabel}! Your total balance is now {wallet.PyCoins} Coins.",
            dataPayload: new()
            {
                ["type"] = "loyalty_earned",
                ["coins_earned"] = coins.ToString(System.Globalization.CultureInfo.InvariantCulture),
                ["total_coins"] = wallet.PyCoins.ToString(System.Globalization.CultureInfo.InvariantCulture),
                ["source"] = sourceType
            },
            cancellationToken: ct);

        _logger.CoinsAwarded(userId, coins, previousBalance, wallet.PyCoins, sourceType);
        return coins;
    }

    /// <summary>
    /// Redeems PY Coins against a platform fee. 1 PY Coin = ₹1.
    /// Called during checkout when the user toggles "Use PY Coins".
    /// Returns the discount amount applied.
    /// </summary>
    public async Task<decimal> RedeemCoinsAsync(
        Guid userId,
        int coinsToRedeem,
        CancellationToken ct = default)
    {
        if (coinsToRedeem <= 0)
            return 0;

        var wallet = await _context.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == userId, ct)
            ?? throw new InvalidOperationException("Wallet not found. Place an order first to start earning PY Coins.");

        if (wallet.PyCoins < coinsToRedeem)
            throw new InvalidOperationException($"Insufficient PY Coins. You have {wallet.PyCoins} coins but tried to redeem {coinsToRedeem}.");

        wallet.DebitCoins(coinsToRedeem);
        await _context.SaveChangesAsync(ct);

        _logger.CoinsRedeemed(userId, coinsToRedeem, wallet.PyCoins);
        return coinsToRedeem; // 1 coin = ₹1
    }

    /// <summary>
    /// Gets the user's current PY Coin balance.
    /// </summary>
    public async Task<int> GetCoinBalanceAsync(Guid userId, CancellationToken ct = default)
    {
        var wallet = await _context.UserWallets
            .AsNoTracking()
            .FirstOrDefaultAsync(w => w.UserId == userId, ct);

        return wallet?.PyCoins ?? 0;
    }
}

internal static partial class LoyaltyLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Awarded {Coins} PY Coins to user {UserId} from {Source}. Balance: {PreviousBalance} → {NewBalance}")]
    public static partial void CoinsAwarded(this ILogger logger, Guid userId, int coins, int previousBalance, int newBalance, string source);

    [LoggerMessage(Level = LogLevel.Information, Message = "Redeemed {Coins} PY Coins for user {UserId}. Remaining balance: {NewBalance}")]
    public static partial void CoinsRedeemed(this ILogger logger, Guid userId, int coins, int newBalance);
}
