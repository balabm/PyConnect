namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A paid promotion purchased by a vendor (top listing, push notification, flash sale, featured banner).
/// </summary>
public sealed class VendorPromotion : BaseEntity
{
    public Guid VendorId { get; private set; }

    public PromoType PromoType { get; private set; }

    public string Title { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public double? TargetLatitude { get; private set; }

    public double? TargetLongitude { get; private set; }

    public double? TargetRadiusKm { get; private set; }

    public decimal Cost { get; private set; }

    public decimal? DiscountPercentage { get; private set; }

    public DateTimeOffset StartsAt { get; private set; }

    public DateTimeOffset ExpiresAt { get; private set; }

    public bool IsActive { get; private set; } = true;

    public Vendor? Vendor { get; private set; }

    private VendorPromotion()
    {
        // EF Core
    }

    public static VendorPromotion Create(
        Guid vendorId,
        PromoType promoType,
        string title,
        decimal cost,
        DateTimeOffset startsAt,
        DateTimeOffset expiresAt,
        string? description = null,
        double? targetLatitude = null,
        double? targetLongitude = null,
        double? targetRadiusKm = null,
        decimal? discountPercentage = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(title);
        ArgumentOutOfRangeException.ThrowIfNegative(cost);
        if (expiresAt <= startsAt) throw new ArgumentException("ExpiresAt must be after StartsAt");
        if (discountPercentage.HasValue && (discountPercentage.Value < 0 || discountPercentage.Value > 100))
            throw new ArgumentOutOfRangeException(nameof(discountPercentage), "Discount must be between 0 and 100.");

        return new VendorPromotion
        {
            VendorId = vendorId,
            PromoType = promoType,
            Title = title,
            Cost = cost,
            StartsAt = startsAt,
            ExpiresAt = expiresAt,
            Description = description,
            TargetLatitude = targetLatitude,
            TargetLongitude = targetLongitude,
            TargetRadiusKm = targetRadiusKm,
            DiscountPercentage = discountPercentage
        };
    }

    public void SetDiscount(decimal percentage)
    {
        if (percentage < 0 || percentage > 100)
            throw new ArgumentOutOfRangeException(nameof(percentage), "Discount must be between 0 and 100.");
        DiscountPercentage = percentage;
        MarkUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkUpdated();
    }

    public bool IsValidAt(DateTimeOffset at) => IsActive && at >= StartsAt && at <= ExpiresAt;
}