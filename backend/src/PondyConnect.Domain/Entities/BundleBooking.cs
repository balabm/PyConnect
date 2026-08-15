namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using System.Collections.Generic;

/// <summary>
/// A bundled package booking (e.g., "Long Weekend Pass") containing multiple services at a discounted price.
/// </summary>
public sealed class BundleBooking : BaseEntity
{
    public Guid UserId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public decimal TotalPrice { get; private set; }

    public decimal DiscountedPrice { get; private set; }

    public BundleStatus Status { get; private set; } = BundleStatus.Active;

    public DateTimeOffset? ExpiresAt { get; private set; }

    public string? PassToken { get; private set; }

    public PassType PassType { get; private set; } = PassType.WeekendPass;

    public IReadOnlyList<BundleItem> Items => _items.AsReadOnly();

    private readonly List<BundleItem> _items = [];

    private BundleBooking()
    {
        // EF Core
    }

    public static BundleBooking Create(
        Guid userId,
        string name,
        decimal totalPrice,
        decimal discountedPrice,
        string? description = null,
        DateTimeOffset? expiresAt = null,
        PassType passType = PassType.WeekendPass)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfNegative(totalPrice);
        ArgumentOutOfRangeException.ThrowIfNegative(discountedPrice);
        if (discountedPrice > totalPrice) throw new ArgumentException("Discounted price cannot exceed total price");

        return new BundleBooking
        {
            UserId = userId,
            Name = name,
            TotalPrice = totalPrice,
            DiscountedPrice = discountedPrice,
            Description = description,
            ExpiresAt = expiresAt,
            PassType = passType
        };
    }

    public void AddItem(BundleItem item)
    {
        _items.Add(item);
        MarkUpdated();
    }

    public void MarkPartiallyRedeemed()
    {
        Status = BundleStatus.PartiallyRedeemed;
        MarkUpdated();
    }

    public void MarkFullyRedeemed()
    {
        Status = BundleStatus.FullyRedeemed;
        MarkUpdated();
    }

    public void Cancel()
    {
        Status = BundleStatus.Cancelled;
        MarkUpdated();
    }

    public void IssuePass(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        PassToken = token;
        MarkUpdated();
    }
}

/// <summary>
/// An individual service/component within a bundle booking.
/// </summary>
public sealed class BundleItem : BaseEntity
{
    public Guid BundleBookingId { get; private set; }

    public string ServiceName { get; private set; } = string.Empty;

    public string? ServiceReferenceId { get; private set; } // e.g., booking ID, rental ID, etc.

    public ExperienceCategory? ExperienceCategory { get; private set; }

    public decimal OriginalPrice { get; private set; }

    public bool IsRedeemed { get; private set; }

    public DateTimeOffset? RedeemedAt { get; private set; }

    public BundleBooking? BundleBooking { get; private set; }

    private BundleItem()
    {
        // EF Core
    }

    public static BundleItem Create(
        Guid bundleBookingId,
        string serviceName,
        decimal originalPrice,
        string? serviceReferenceId = null,
        ExperienceCategory? experienceCategory = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(serviceName);
        ArgumentOutOfRangeException.ThrowIfNegative(originalPrice);

        return new BundleItem
        {
            BundleBookingId = bundleBookingId,
            ServiceName = serviceName,
            OriginalPrice = originalPrice,
            ServiceReferenceId = serviceReferenceId,
            ExperienceCategory = experienceCategory
        };
    }

    public void Redeem(string referenceId)
    {
        IsRedeemed = true;
        ServiceReferenceId = referenceId;
        RedeemedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}