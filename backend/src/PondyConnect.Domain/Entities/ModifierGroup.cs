namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A group of modifiers (e.g. "Choose Size", "Choose Crust",
/// "Extra Toppings") that a consumer can select when ordering a menu item.
/// </summary>
public sealed class ModifierGroup : BaseEntity
{
    public Guid MenuItemId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public int MinSelections { get; private set; }

    public int MaxSelections { get; private set; }

    public int SortOrder { get; private set; }

    /// <summary>
    /// Convenience flag — true when <see cref="MinSelections"/> is greater
    /// than zero, meaning the consumer must select at least one modifier.
    /// </summary>
    public bool IsRequired => MinSelections > 0;

    public MenuItem? MenuItem { get; private set; }

    private readonly List<Modifier> _modifiers = [];
    public IReadOnlyCollection<Modifier> Modifiers => _modifiers.AsReadOnly();

    private ModifierGroup()
    {
    }

    public static ModifierGroup Create(
        Guid menuItemId,
        string name,
        int minSelections = 0,
        int maxSelections = 0,
        int sortOrder = 0)
    {
        if (menuItemId == Guid.Empty)
            throw new ArgumentException("Menu item ID is required.", nameof(menuItemId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);

        if (minSelections < 0)
            throw new ArgumentOutOfRangeException(nameof(minSelections), "MinSelections cannot be negative.");
        if (maxSelections < 0)
            throw new ArgumentOutOfRangeException(nameof(maxSelections), "MaxSelections cannot be negative.");
        if (maxSelections > 0 && maxSelections < minSelections)
            throw new ArgumentOutOfRangeException(nameof(maxSelections), "MaxSelections cannot be less than MinSelections.");

        return new ModifierGroup
        {
            MenuItemId = menuItemId,
            Name = name,
            MinSelections = minSelections,
            MaxSelections = maxSelections,
            SortOrder = sortOrder
        };
    }

    public void Update(string name, int minSelections, int maxSelections, int sortOrder)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        if (minSelections < 0)
            throw new ArgumentOutOfRangeException(nameof(minSelections), "MinSelections cannot be negative.");
        if (maxSelections < 0)
            throw new ArgumentOutOfRangeException(nameof(maxSelections), "MaxSelections cannot be negative.");
        if (maxSelections > 0 && maxSelections < minSelections)
            throw new ArgumentOutOfRangeException(nameof(maxSelections), "MaxSelections cannot be less than MinSelections.");

        Name = name;
        MinSelections = minSelections;
        MaxSelections = maxSelections;
        SortOrder = sortOrder;
        MarkUpdated();
    }

    public void AddModifier(Modifier modifier)
    {
        ArgumentNullException.ThrowIfNull(modifier);
        _modifiers.Add(modifier);
        MarkUpdated();
    }
}
