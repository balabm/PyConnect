namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A single selectable modifier within a <see cref="ModifierGroup"/>
/// (e.g. "10 Inch", "12 Inch", "Extra Cheese"). The <see cref="Price"/>
/// is added on top of the base menu item price when selected.
/// </summary>
public sealed class Modifier : BaseEntity
{
    public Guid ModifierGroupId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public decimal Price { get; private set; }

    public bool IsAvailable { get; private set; } = true;

    public int SortOrder { get; private set; }

    public ModifierGroup? ModifierGroup { get; private set; }

    private Modifier()
    {
    }

    public static Modifier Create(
        Guid modifierGroupId,
        string name,
        decimal price = 0m,
        bool isAvailable = true,
        int sortOrder = 0)
    {
        if (modifierGroupId == Guid.Empty)
            throw new ArgumentException("Modifier group ID is required.", nameof(modifierGroupId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfNegative(price, nameof(price));

        return new Modifier
        {
            ModifierGroupId = modifierGroupId,
            Name = name,
            Price = price,
            IsAvailable = isAvailable,
            SortOrder = sortOrder
        };
    }

    public void Update(string name, decimal price, bool isAvailable)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfNegative(price, nameof(price));

        Name = name;
        Price = price;
        IsAvailable = isAvailable;
        MarkUpdated();
    }

    public void ToggleAvailability()
    {
        IsAvailable = !IsAvailable;
        MarkUpdated();
    }
}
