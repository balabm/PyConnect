namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Tracks a referral relationship between an existing user (referrer)
/// and a newly invited user (referred). The referrer's reward is
/// deferred until the referred user completes their first paid order,
/// preventing fake-account fraud.
/// </summary>
public sealed class Referral : BaseEntity
{
    public Guid ReferrerId { get; private set; }

    public Guid ReferredUserId { get; private set; }

    /// <summary>
    /// The referral code used (e.g., "BALA50"). Stored for audit.
    /// </summary>
    public string ReferralCode { get; private set; } = string.Empty;

    public ReferralStatus Status { get; private set; } = ReferralStatus.Pending;

    /// <summary>
    /// Welcome credit applied to the referred user's wallet on signup.
    /// </summary>
    public decimal WelcomeCredit { get; private set; }

    /// <summary>
    /// Reward credited to the referrer after the referred user's first
    /// paid order completes.
    /// </summary>
    public decimal ReferrerReward { get; private set; }

    public DateTimeOffset? CompletedAt { get; private set; }

    /// <summary>
    /// The order/ride ID that triggered the referral completion.
    /// </summary>
    public Guid? TriggeringOrderId { get; private set; }

    private Referral()
    {
    }

    public static Referral Create(
        Guid referrerId,
        Guid referredUserId,
        string referralCode,
        decimal welcomeCredit = 50m,
        decimal referrerReward = 50m)
    {
        if (referrerId == Guid.Empty)
            throw new ArgumentException("Referrer ID is required.", nameof(referrerId));
        if (referredUserId == Guid.Empty)
            throw new ArgumentException("Referred user ID is required.", nameof(referredUserId));
        if (referrerId == referredUserId)
            throw new InvalidOperationException("Cannot refer yourself.");
        ArgumentException.ThrowIfNullOrWhiteSpace(referralCode);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(welcomeCredit, nameof(welcomeCredit));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(referrerReward, nameof(referrerReward));

        return new Referral
        {
            ReferrerId = referrerId,
            ReferredUserId = referredUserId,
            ReferralCode = referralCode,
            WelcomeCredit = welcomeCredit,
            ReferrerReward = referrerReward,
            Status = ReferralStatus.Pending
        };
    }

    /// <summary>
    /// Mark the referral as completed after the referred user's first
    /// paid order. Records the triggering order ID for audit.
    /// </summary>
    public void Complete(Guid triggeringOrderId)
    {
        if (Status != ReferralStatus.Pending)
            throw new InvalidOperationException("Referral is already completed or revoked.");
        if (triggeringOrderId == Guid.Empty)
            throw new ArgumentException("Triggering order ID is required.", nameof(triggeringOrderId));

        Status = ReferralStatus.Completed;
        CompletedAt = DateTimeOffset.UtcNow;
        TriggeringOrderId = triggeringOrderId;
        MarkUpdated();
    }

    /// <summary>
    /// Revoke the referral (e.g., if the referred user's account is
    /// deactivated for fraud within the cooling period).
    /// </summary>
    public void Revoke(string reason)
    {
        if (Status == ReferralStatus.Revoked)
            return;

        Status = ReferralStatus.Revoked;
        MarkUpdated();
    }
}
