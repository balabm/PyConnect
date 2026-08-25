namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A finite hardware asset owned by a PartySupplier vendor (speakers,
/// lights, smoke machines). Unlike a food menu, units are finite and
/// tracked per-item. When <see cref="AvailableUnits"/> hits 0 the item
/// shows as "Sold Out" on the Consumer app for the requested dates.
/// </summary>
public sealed class EquipmentItem : BaseEntity
{
    public Guid VendorId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    /// <summary>
    /// Daily rental price in INR.
    /// </summary>
    public decimal DailyRentalPrice { get; private set; }

    /// <summary>
    /// Required security deposit amount (held via Razorpay auth-hold).
    /// </summary>
    public decimal SecurityDepositAmount { get; private set; }

    public int TotalUnits { get; private set; }

    public int AvailableUnits { get; private set; }

    public string Category { get; private set; } = "Misc";

    public string? ImageUrl { get; private set; }

    public bool IsAvailable { get; private set; } = true;

    private EquipmentItem()
    {
        // EF Core constructor.
    }

    public static EquipmentItem Create(
        Guid vendorId,
        string name,
        decimal dailyRentalPrice,
        decimal securityDepositAmount,
        int totalUnits,
        string category = "Misc",
        string? description = null,
        string? imageUrl = null)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(category);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(dailyRentalPrice, nameof(dailyRentalPrice));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(securityDepositAmount, nameof(securityDepositAmount));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(totalUnits, nameof(totalUnits));

        return new EquipmentItem
        {
            VendorId = vendorId,
            Name = name,
            DailyRentalPrice = dailyRentalPrice,
            SecurityDepositAmount = securityDepositAmount,
            TotalUnits = totalUnits,
            AvailableUnits = totalUnits,
            Category = category,
            Description = description,
            ImageUrl = imageUrl,
            IsAvailable = true
        };
    }

    public void UpdatePricing(decimal dailyRentalPrice, decimal securityDepositAmount)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(dailyRentalPrice, nameof(dailyRentalPrice));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(securityDepositAmount, nameof(securityDepositAmount));
        DailyRentalPrice = dailyRentalPrice;
        SecurityDepositAmount = securityDepositAmount;
        MarkUpdated();
    }

    public void AdjustStock(int delta)
    {
        var newAvailable = AvailableUnits + delta;
        if (newAvailable < 0)
            throw new InvalidOperationException("Available units cannot go below zero.");
        if (newAvailable > TotalUnits)
            throw new InvalidOperationException("Available units cannot exceed total units.");
        AvailableUnits = newAvailable;
        IsAvailable = AvailableUnits > 0;
        MarkUpdated();
    }

    public void ReserveUnits(int count)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (count > AvailableUnits)
            throw new InvalidOperationException("Not enough available units to reserve.");
        AvailableUnits -= count;
        if (AvailableUnits == 0)
            IsAvailable = false;
        MarkUpdated();
    }

    public void RestoreUnits(int count)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        var restored = AvailableUnits + count;
        if (restored > TotalUnits)
            restored = TotalUnits;
        AvailableUnits = restored;
        IsAvailable = AvailableUnits > 0;
        MarkUpdated();
    }

    public void MarkUnavailable()
    {
        IsAvailable = false;
        MarkUpdated();
    }

    public void MarkAvailable()
    {
        IsAvailable = AvailableUnits > 0;
        MarkUpdated();
    }
}
