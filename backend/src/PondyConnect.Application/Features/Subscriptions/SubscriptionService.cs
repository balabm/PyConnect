namespace PondyConnect.Application.Features.Subscriptions;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;

/// <summary>
/// Manages PY Prime subscriptions: activation, renewal, grace period,
/// and automatic deactivation when eMandate fails.
/// </summary>
public sealed class SubscriptionService
{
    /// <summary>
    /// Grace period (days) before IsPrime is revoked after a renewal failure.
    /// During this window, the user retains Prime benefits while we retry.
    /// </summary>
    public const int GracePeriodDays = 3;

    /// <summary>
    /// Monthly subscription price for PY Prime.
    /// </summary>
    public const decimal MonthlyPrice = 199m;

    /// <summary>
    /// Subscription duration in days for one monthly cycle.
    /// </summary>
    public const int MonthlyDurationDays = 30;

    private readonly IApplicationDbContext _context;
    private readonly INotificationService _notifications;
    private readonly ILogger<SubscriptionService> _logger;

    public SubscriptionService(
        IApplicationDbContext context,
        INotificationService notifications,
        ILogger<SubscriptionService> logger)
    {
        _context = context;
        _notifications = notifications;
        _logger = logger;
    }

    /// <summary>
    /// Activates a Prime subscription for a user after successful payment.
    /// </summary>
    public async Task ActivatePrimeAsync(
        Guid userId,
        string? paymentReference = null,
        CancellationToken ct = default)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, ct)
            ?? throw new InvalidOperationException("User not found.");

        user.ActivateProMembership(MonthlyDurationDays);
        await _context.SaveChangesAsync(ct);

        // Record the subscription
        var plan = await GetOrCreatePrimePlanAsync(ct);
        var subscription = UserSubscription.Create(
            userId: userId,
            subscriptionPlanId: plan.Id,
            startsAt: DateTimeOffset.UtcNow,
            durationDays: MonthlyDurationDays,
            paymentReference: paymentReference);

        _context.UserSubscriptions.Add(subscription);
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Activated PY Prime for user {UserId}, expires {ExpiresAt}",
            userId, user.ProMemberUntil);

        await _notifications.SendTargetedPushAsync(
            userId,
            "PY Prime Activated",
            $"Enjoy free delivery on orders above ₹{PrimeMinOrderText}!",
            cancellationToken: ct);
    }

    /// <summary>
    /// Handles a subscription renewal failure from Razorpay eMandate.
    /// Starts a 3-day grace period. On day 4, IsPrime is revoked.
    /// </summary>
    public async Task HandleRenewalFailureAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
        if (user is null) return;

        // Check if we're already in a grace period
        var graceUntil = user.ProMemberUntil?.AddDays(GracePeriodDays);

        if (graceUntil.HasValue && graceUntil.Value > DateTimeOffset.UtcNow)
        {
            _logger.LogInformation(
                "User {UserId} already in grace period until {GraceUntil}",
                userId, graceUntil);
            return;
        }

        // Extend ProMemberUntil by the grace period
        // (the user keeps benefits during grace)
        if (user.ProMemberUntil.HasValue)
        {
            // Don't extend if already past — just let the worker revoke
            _logger.LogWarning(
                "PY Prime renewal failed for user {UserId}. Grace period active until {GraceUntil}",
                userId, graceUntil);
        }

        await _notifications.SendTargetedPushAsync(
            userId,
            "PY Prime Renewal Failed",
            $"Your subscription renewal failed. You have a {GracePeriodDays}-day grace period to update your payment method.",
            cancellationToken: ct);
    }

    /// <summary>
    /// Checks all Prime subscriptions and revokes access for users
    /// whose grace period has expired. Called by SubscriptionWorker daily.
    /// </summary>
    public async Task<int> RevokeExpiredSubscriptionsAsync(CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;
        var graceCutoff = now.AddDays(-GracePeriodDays);

        var expiredUsers = await _context.Users
            .Where(u => u.IsProMember
                && u.ProMemberUntil.HasValue
                && u.ProMemberUntil.Value < now
                && u.ProMemberUntil.Value < graceCutoff)
            .ToListAsync(ct);

        if (expiredUsers.Count == 0)
            return 0;

        foreach (var user in expiredUsers)
        {
            user.DeactivateProMembership();

            await _notifications.SendTargetedPushAsync(
                user.Id,
                "PY Prime Expired",
                "Your PY Prime subscription has expired. Renew to continue enjoying free delivery.",
                cancellationToken: ct);
        }

        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Revoked PY Prime for {Count} users (grace period expired)",
            expiredUsers.Count);

        return expiredUsers.Count;
    }

    /// <summary>
    /// Gets the user's current Prime status including grace period info.
    /// </summary>
    public async Task<PrimeStatusResponse> GetPrimeStatusAsync(
        Guid userId,
        CancellationToken ct = default)
    {
        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        if (user is null)
            throw new InvalidOperationException("User not found.");

        var isActive = user.IsProMember && user.ProMemberUntil > DateTimeOffset.UtcNow;
        var inGracePeriod = user.IsProMember
            && user.ProMemberUntil <= DateTimeOffset.UtcNow
            && user.ProMemberUntil?.AddDays(GracePeriodDays) > DateTimeOffset.UtcNow;

        return new PrimeStatusResponse(
            IsPrime: isActive,
            ExpiresAt: user.ProMemberUntil,
            InGracePeriod: inGracePeriod,
            GracePeriodDays: inGracePeriod ? GracePeriodDays : 0,
            MonthlyPrice: MonthlyPrice);
    }

    private async Task<SubscriptionPlan> GetOrCreatePrimePlanAsync(CancellationToken ct)
    {
        var existing = await _context.SubscriptionPlans
            .FirstOrDefaultAsync(p => p.PlanType == SubscriptionPlanType.Pro && p.IsActive, ct);

        if (existing is not null)
            return existing;

        var plan = SubscriptionPlan.Create(
            name: "PY Prime",
            planType: SubscriptionPlanType.Pro,
            price: MonthlyPrice,
            durationDays: MonthlyDurationDays,
            description: "Free delivery on orders above ₹149, exclusive perks");

        _context.SubscriptionPlans.Add(plan);
        await _context.SaveChangesAsync(ct);

        return plan;
    }

    private const string PrimeMinOrderText = "149";
}

public sealed record PrimeStatusResponse(
    bool IsPrime,
    DateTimeOffset? ExpiresAt,
    bool InGracePeriod,
    int GracePeriodDays,
    decimal MonthlyPrice);
