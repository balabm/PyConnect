namespace PondyConnect.Application.Features.Referral;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;

/// <summary>
/// Manages the viral referral engine: code generation, welcome credit
/// on signup, and deferred referrer payout after the referred user's
/// first paid order completes.
/// </summary>
public sealed class ReferralService
{
    public const decimal WelcomeCreditAmount = 50m;
    public const decimal ReferrerRewardAmount = 50m;

    private readonly IApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<ReferralService> _logger;

    public ReferralService(
        IApplicationDbContext context,
        INotificationService notifications,
        ILogger<ReferralService> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    /// <summary>
    /// Processes a referral code provided during signup. If the code is
    /// valid and belongs to a different user, creates a Referral record
    /// and credits the welcome amount to the new user's wallet.
    /// </summary>
    public async Task<bool> ProcessReferralCodeAsync(
        Guid newUserId,
        string referralCode,
        CancellationToken ct = default)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(referralCode);
        referralCode = referralCode.Trim().ToUpperInvariant();

        // Find the referrer by their referral code
        var referrer = await _context.Users
            .FirstOrDefaultAsync(u => u.ReferralCode == referralCode, ct);
        if (referrer is null || referrer.Id == newUserId)
            return false;

        // Check if this user was already referred (idempotency)
        var existing = await _context.Referrals
            .AnyAsync(r => r.ReferredUserId == newUserId, ct);
        if (existing)
            return false;

        // Create the referral record
        var referral = Referral.Create(
            referrer.Id,
            newUserId,
            referralCode,
            WelcomeCreditAmount,
            ReferrerRewardAmount);
        _context.Referrals.Add(referral);

        // Credit welcome amount to the new user's wallet
        var wallet = await _context.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == newUserId, ct);
        if (wallet is null)
        {
            wallet = UserWallet.Create(newUserId, promoBalance: WelcomeCreditAmount);
            _context.UserWallets.Add(wallet);
        }
        else
        {
            wallet.CreditPromo(WelcomeCreditAmount);
        }

        await _context.SaveChangesAsync(ct);

        _logger.ReferralCreated(referrer.Id, newUserId, referralCode, WelcomeCreditAmount);

        // Send welcome push to the new user
        _ = _notifications.SendTargetedPushAsync(
            newUserId,
            "Welcome to PY Connect!",
            $"₹{WelcomeCreditAmount:F0} welcome credit added to your wallet. Enjoy your first order!",
            dataPayload: new() { ["type"] = "referral_welcome", ["amount"] = WelcomeCreditAmount.ToString("F0", CultureInfo.InvariantCulture) },
            cancellationToken: ct);

        return true;
    }

    /// <summary>
    /// Called when an order or ride completes. Checks if the user was
    /// referred and if this is their first completed paid order. If so,
    /// credits the referrer's wallet and sends them a push notification.
    /// </summary>
    public async Task<bool> ProcessOrderCompletionAsync(
        Guid userId,
        Guid orderId,
        CancellationToken ct = default)
    {
        // Find a pending referral for this user
        var referral = await _context.Referrals
            .FirstOrDefaultAsync(r => r.ReferredUserId == userId && r.Status == ReferralStatus.Pending, ct);
        if (referral is null)
            return false;

        // Complete the referral
        referral.Complete(orderId);

        // Credit the referrer's wallet
        var referrerWallet = await _context.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == referral.ReferrerId, ct);
        if (referrerWallet is null)
        {
            referrerWallet = UserWallet.Create(referral.ReferrerId, promoBalance: 0m);
            _context.UserWallets.Add(referrerWallet);
        }
        referrerWallet.CreditPromo(referral.ReferrerReward);

        await _context.SaveChangesAsync(ct);

        _logger.ReferralCompleted(referral.ReferrerId, userId, referral.ReferrerReward);

        // Send push to the referrer
        _ = _notifications.SendTargetedPushAsync(
            referral.ReferrerId,
            "Your friend just ordered!",
            $"Your friend completed their first order. ₹{referral.ReferrerReward:F0} has been added to your wallet!",
            dataPayload: new() { ["type"] = "referral_completed", ["amount"] = referral.ReferrerReward.ToString("F0", CultureInfo.InvariantCulture) },
            cancellationToken: ct);

        return true;
    }

    /// <summary>
    /// Gets referral statistics for a user: how many people they've
    /// referred, how many completed, and total rewards earned.
    /// </summary>
    public async Task<ReferralStats> GetStatsAsync(Guid userId, CancellationToken ct = default)
    {
        var referrals = await _context.Referrals
            .Where(r => r.ReferrerId == userId)
            .ToListAsync(ct);

        return new ReferralStats(
            TotalReferred: referrals.Count,
            Completed: referrals.Count(r => r.Status == ReferralStatus.Completed),
            Pending: referrals.Count(r => r.Status == ReferralStatus.Pending),
            TotalEarned: referrals.Where(r => r.Status == ReferralStatus.Completed).Sum(r => r.ReferrerReward));
    }
}

public sealed record ReferralStats(int TotalReferred, int Completed, int Pending, decimal TotalEarned);

internal static partial class ReferralLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Referral created: Referrer {ReferrerId} → User {NewUserId} (code: {Code}, welcome: ₹{Welcome}")]
    public static partial void ReferralCreated(this ILogger logger, Guid referrerId, Guid newUserId, string code, decimal welcome);

    [LoggerMessage(Level = LogLevel.Information, Message = "Referral completed: Referrer {ReferrerId} earned ₹{Reward} from user {NewUserId}")]
    public static partial void ReferralCompleted(this ILogger logger, Guid referrerId, Guid newUserId, decimal reward);
}
