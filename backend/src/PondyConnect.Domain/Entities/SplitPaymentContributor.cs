namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Tracks an individual contributor's share in a split payment pool.
/// Each contributor claims a share and pays their portion via Razorpay.
/// </summary>
public sealed class SplitPaymentContributor : BaseEntity
{
    public Guid PoolId { get; private set; }

    public Guid UserId { get; private set; }

    public decimal ShareAmount { get; private set; }

    public decimal PaidAmount { get; private set; }

    public ContributorStatus Status { get; private set; } = ContributorStatus.Pending;

    public DateTimeOffset? PaidAt { get; private set; }

    private SplitPaymentContributor()
    {
        // EF Core constructor.
    }

    public static SplitPaymentContributor Create(
        Guid poolId,
        Guid userId,
        decimal shareAmount)
    {
        if (poolId == Guid.Empty)
            throw new ArgumentException("Pool ID is required.", nameof(poolId));
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(shareAmount, nameof(shareAmount));

        return new SplitPaymentContributor
        {
            PoolId = poolId,
            UserId = userId,
            ShareAmount = shareAmount,
            PaidAmount = 0m,
            Status = ContributorStatus.Pending
        };
    }

    /// <summary>
    /// Marks this contributor's share as paid with the given amount.
    /// </summary>
    public void MarkPaid()
    {
        if (Status == ContributorStatus.Paid)
            throw new InvalidOperationException("This contributor has already paid.");
        if (Status == ContributorStatus.Refunded)
            throw new InvalidOperationException("Cannot mark a refunded contributor as paid.");

        PaidAmount = ShareAmount;
        Status = ContributorStatus.Paid;
        PaidAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Marks this contributor's share as refunded.
    /// </summary>
    public void MarkRefunded()
    {
        if (Status != ContributorStatus.Paid)
            throw new InvalidOperationException("Only paid contributors can be refunded.");

        Status = ContributorStatus.Refunded;
        PaidAmount = 0m;
        PaidAt = null;
        MarkUpdated();
    }
}
