namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A menu item offered by a vendor or venue for food delivery.
/// </summary>
public sealed class MenuItem : BaseEntity
{
    public Guid VendorId { get; private set; }

    public Guid? VenueId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public decimal Price { get; private set; }

    public string Category { get; private set; } = string.Empty;

    public bool IsAvailable { get; private set; } = true;

    public string? ImageUrl { get; private set; }

    public bool IsLateNight { get; private set; }

    public bool IsVeg { get; private set; } = true;

    public bool IsVegan { get; private set; }

    public bool ContainsNuts { get; private set; }

    public int? PrepTimeMinutes { get; private set; }

    public decimal PackagingFee { get; private set; }

    private readonly List<ModifierGroup> _modifierGroups = [];
    public IReadOnlyCollection<ModifierGroup> ModifierGroups => _modifierGroups.AsReadOnly();

    private MenuItem()
    {
    }

    public static MenuItem Create(
        Guid vendorId,
        string name,
        decimal price,
        string category,
        Guid? venueId = null,
        string? description = null,
        string? imageUrl = null,
        bool isLateNight = false,
        bool isVeg = true,
        bool isVegan = false,
        bool containsNuts = false,
        int? prepTimeMinutes = null,
        decimal packagingFee = 0)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(category);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(price, nameof(price));
        if (packagingFee < 0)
            throw new ArgumentOutOfRangeException(nameof(packagingFee), "Packaging fee cannot be negative.");

        return new MenuItem
        {
            VendorId = vendorId,
            VenueId = venueId,
            Name = name,
            Price = price,
            Category = category,
            Description = description,
            ImageUrl = imageUrl,
            IsLateNight = isLateNight,
            IsVeg = isVeg,
            IsVegan = isVegan,
            ContainsNuts = containsNuts,
            PrepTimeMinutes = prepTimeMinutes,
            PackagingFee = packagingFee
        };
    }

    public void UpdatePrice(decimal newPrice)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(newPrice, nameof(newPrice));
        Price = newPrice;
        MarkUpdated();
    }

    public void UpdateDetails(string name, string? description, string category, string? imageUrl = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(category);
        Name = name;
        Description = description;
        Category = category;
        if (imageUrl != null)
            ImageUrl = imageUrl;
        MarkUpdated();
    }

    public void UpdateDietaryTags(bool isVeg, bool isVegan, bool containsNuts)
    {
        IsVeg = isVeg;
        IsVegan = isVegan;
        ContainsNuts = containsNuts;
        MarkUpdated();
    }

    public void UpdatePrepTime(int? prepTimeMinutes)
    {
        if (prepTimeMinutes.HasValue && prepTimeMinutes.Value <= 0)
            throw new ArgumentOutOfRangeException(nameof(prepTimeMinutes), "Prep time must be positive.");
        PrepTimeMinutes = prepTimeMinutes;
        MarkUpdated();
    }

    public void UpdatePackagingFee(decimal packagingFee)
    {
        if (packagingFee < 0)
            throw new ArgumentOutOfRangeException(nameof(packagingFee), "Packaging fee cannot be negative.");
        PackagingFee = packagingFee;
        MarkUpdated();
    }

    public void ToggleAvailability()
    {
        IsAvailable = !IsAvailable;
        MarkUpdated();
    }
}
