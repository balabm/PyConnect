namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A user's active or expired subscription to a plan.
/// </summary>
public sealed class UserSubscription : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid SubscriptionPlanId { get; private set; }

    public DateTimeOffset StartsAt { get; private set; }

    public DateTimeOffset ExpiresAt { get; private set; }

    public bool IsActive { get; private set; }

    public string? PaymentReference { get; private set; }

    public SubscriptionPlan? Plan { get; private set; }

    private UserSubscription()
    {
        // EF Core
    }

    public static UserSubscription Create(
        Guid userId,
        Guid subscriptionPlanId,
        DateTimeOffset startsAt,
        int durationDays,
        string? paymentReference = null)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(durationDays);

        return new UserSubscription
        {
            UserId = userId,
            SubscriptionPlanId = subscriptionPlanId,
            StartsAt = startsAt,
            ExpiresAt = startsAt.AddDays(durationDays),
            IsActive = true,
            PaymentReference = paymentReference
        };
    }

    public void Cancel()
    {
        if (!IsActive)
            return; // idempotent: already cancelled
        IsActive = false;
        MarkUpdated();
    }

    public bool IsValidAt(DateTimeOffset at) => IsActive && at >= StartsAt && at <= ExpiresAt;
}