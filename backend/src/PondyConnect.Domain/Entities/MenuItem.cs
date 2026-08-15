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
        bool isLateNight = false)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(category);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(price, nameof(price));

        return new MenuItem
        {
            VendorId = vendorId,
            VenueId = venueId,
            Name = name,
            Price = price,
            Category = category,
            Description = description,
            ImageUrl = imageUrl,
            IsLateNight = isLateNight
        };
    }

    public void UpdatePrice(decimal newPrice)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(newPrice, nameof(newPrice));
        Price = newPrice;
        MarkUpdated();
    }

    public void UpdateDetails(string name, string? description, string category)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(category);
        Name = name;
        Description = description;
        Category = category;
        MarkUpdated();
    }

    public void ToggleAvailability()
    {
        IsAvailable = !IsAvailable;
        MarkUpdated();
    }
}
