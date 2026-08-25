namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A split payment pool for high-ticket items (villa rentals, yacht charters).
/// The creator sets a total amount and number of shares, then shares a deep-link
/// URL via WhatsApp so friends can claim and pay their individual shares.
/// </summary>
public sealed class SplitPaymentPool : BaseEntity
{
    public Guid CreatorUserId { get; private set; }

    public decimal TotalAmount { get; private set; }

    public decimal CollectedAmount { get; private set; }

    public string Description { get; private set; } = string.Empty;

    /// <summary>
    /// Optional link to the originating booking/resource
    /// (e.g. "StayBooking", "Rental").
    /// </summary>
    public string? ReferenceType { get; private set; }

    public Guid? ReferenceId { get; private set; }

    /// <summary>
    /// URL-safe unique slug used in the deep-link shared via WhatsApp
    /// (e.g. "a1b2c3d4").
    /// </summary>
    public string DeepLinkSlug { get; private set; } = string.Empty;

    public SplitPaymentStatus Status { get; private set; } = SplitPaymentStatus.Active;

    public decimal PerShareAmount { get; private set; }

    public int MaxShares { get; private set; }

    public int ClaimedShares { get; private set; }

    public DateTimeOffset ExpiresAt { get; private set; }

    private SplitPaymentPool()
    {
        // EF Core constructor.
    }

    public static SplitPaymentPool Create(
        Guid creatorUserId,
        decimal totalAmount,
        string description,
        string deepLinkSlug,
        int maxShares,
        DateTimeOffset expiresAt,
        string? referenceType = null,
        Guid? referenceId = null)
    {
        if (creatorUserId == Guid.Empty)
            throw new ArgumentException("Creator user ID is required.", nameof(creatorUserId));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(totalAmount, nameof(totalAmount));
        ArgumentException.ThrowIfNullOrWhiteSpace(description);
        ArgumentException.ThrowIfNullOrWhiteSpace(deepLinkSlug);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(maxShares, nameof(maxShares));
        if (expiresAt <= DateTimeOffset.UtcNow)
            throw new ArgumentException("Expiry must be in the future.", nameof(expiresAt));

        return new SplitPaymentPool
        {
            CreatorUserId = creatorUserId,
            TotalAmount = totalAmount,
            CollectedAmount = 0m,
            Description = description,
            DeepLinkSlug = deepLinkSlug,
            MaxShares = maxShares,
            PerShareAmount = Math.Round(totalAmount / maxShares, 2, MidpointRounding.AwayFromZero),
            ExpiresAt = expiresAt,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
            Status = SplitPaymentStatus.Active
        };
    }

    /// <summary>
    /// Returns true when a new share can be claimed (shares remaining, not
    /// expired/cancelled/fully paid).
    /// </summary>
    public bool CanClaim()
        => Status == SplitPaymentStatus.Active
           && ClaimedShares < MaxShares
           && ExpiresAt > DateTimeOffset.UtcNow;

    /// <summary>
    /// Claims a share for the given user. Increments the claimed share count.
    /// </summary>
    public void ClaimShare(Guid userId)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        if (!CanClaim())
            throw new InvalidOperationException("This split payment pool is no longer accepting claims.");
        ClaimedShares++;
        MarkUpdated();
    }

    /// <summary>
    /// Records a payment from a contributor and updates the pool's collected
    /// amount. Automatically transitions to FullyPaid when the total is reached.
    /// </summary>
    public void MarkPaid(Guid userId, decimal amount)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));
        if (Status is SplitPaymentStatus.Cancelled or SplitPaymentStatus.Expired)
            throw new InvalidOperationException("Cannot pay into a cancelled or expired pool.");

        CollectedAmount += amount;
        if (CollectedAmount >= TotalAmount && Status == SplitPaymentStatus.Active)
            Status = SplitPaymentStatus.FullyPaid;
        MarkUpdated();
    }

    /// <summary>
    /// Manually marks the pool as fully paid (e.g. admin reconciliation).
    /// </summary>
    public void Complete()
    {
        if (Status is SplitPaymentStatus.Cancelled)
            throw new InvalidOperationException("A cancelled pool cannot be completed.");
        Status = SplitPaymentStatus.FullyPaid;
        MarkUpdated();
    }

    /// <summary>
    /// Cancels the pool. Only allowed when not already fully paid.
    /// </summary>
    public void Cancel()
    {
        if (Status is SplitPaymentStatus.FullyPaid)
            throw new InvalidOperationException("A fully paid pool cannot be cancelled.");
        if (Status is SplitPaymentStatus.Cancelled)
            throw new InvalidOperationException("Pool is already cancelled.");
        Status = SplitPaymentStatus.Cancelled;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the pool as expired (called when the expiry time has passed).
    /// </summary>
    public void Expire()
    {
        if (Status is SplitPaymentStatus.FullyPaid or SplitPaymentStatus.Cancelled)
            throw new InvalidOperationException("A completed or cancelled pool cannot expire.");
        Status = SplitPaymentStatus.Expired;
        MarkUpdated();
    }
}
