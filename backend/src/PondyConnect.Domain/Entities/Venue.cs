namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A bookable place: pub, club, restaurant, bakery, cafe, pizzeria or
/// experience/monument. Tracks live capacity for the "Vibe Check" feature.
/// </summary>
public sealed class Venue : BaseEntity
{
    public const int MaxOccupancyLimit = 100_000;

    public string Name { get; private set; } = string.Empty;

    public string? Description { get; private set; }

    public VenueCategory Category { get; private set; }

    public GeoLocation Location { get; private set; } = GeoLocation.Zero;

    public int CurrentCapacity { get; private set; }

    public int CheckedInCount { get; private set; }

    public int MaxCapacity { get; private set; }

    public string? Address { get; private set; }

    public Guid? VendorId { get; private set; }

    public bool IsActive { get; private set; } = true;

    public bool IsPriorityPingActive { get; private set; }

    public DateTimeOffset? PriorityPingExpiry { get; private set; }

    public string? ImageUrl { get; private set; }

    public double? Rating { get; private set; }

    public int ReviewCount { get; private set; }

    private readonly List<VenueAvailability> _availability = [];

    public IReadOnlyCollection<VenueAvailability> Availability => _availability.AsReadOnly();

    private Venue()
    {
        // EF Core constructor.
    }

    public static Venue Create(
        string name,
        VenueCategory category,
        GeoLocation location,
        int maxCapacity,
        Guid? vendorId = null,
        string? description = null,
        string? address = null,
        string? imageUrl = null,
        double? rating = null,
        int reviewCount = 0)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(maxCapacity, 0, nameof(maxCapacity));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(maxCapacity, MaxOccupancyLimit, nameof(maxCapacity));

        return new Venue
        {
            Name = name,
            Category = category,
            Location = location,
            MaxCapacity = maxCapacity,
            VendorId = vendorId,
            Description = description,
            Address = address,
            ImageUrl = imageUrl,
            Rating = rating,
            ReviewCount = reviewCount
        };
    }

    public void UpdateDetails(string name, string? description, string? address)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        Name = name;
        Description = description;
        Address = address;
        MarkUpdated();
    }

    public void UpdateCategory(VenueCategory category)
    {
        Category = category;
        MarkUpdated();
    }

    public void UpdateLocation(GeoLocation location)
    {
        Location = location;
        MarkUpdated();
    }

    public void SetOperatingHours(IEnumerable<VenueAvailability> availability)
    {
        _availability.Clear();
        _availability.AddRange(availability);
        MarkUpdated();
    }

    /// <summary>
    /// Clears the operating-hours collection without tracking removals. The
    /// caller is responsible for removing the rows via the context when
    /// replacing availability during an update.
    /// </summary>
    public void ClearAvailabilityForUpdate()
    {
        _availability.Clear();
        MarkUpdated();
    }

    public void SetMaxCapacity(int maxCapacity)
    {
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(maxCapacity, 0, nameof(maxCapacity));
        if (CurrentCapacity > maxCapacity)
            throw new InvalidOperationException("Max capacity cannot drop below the current occupancy.");
        MaxCapacity = maxCapacity;
        MarkUpdated();
    }

    public bool HasAvailability(int requestedSeats = 1)
        => CurrentCapacity + requestedSeats <= MaxCapacity;

    public void IncreaseOccupancy(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (!HasAvailability(count))
            throw new InvalidOperationException($"Venue '{Name}' is at full capacity.");
        CurrentCapacity += count;
        MarkUpdated();
    }

    public void DecreaseOccupancy(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (CurrentCapacity - count < 0)
            throw new InvalidOperationException("Occupancy cannot go below zero.");
        CurrentCapacity -= count;
        MarkUpdated();
    }

    public void IncrementCheckedIn(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (CheckedInCount + count > CurrentCapacity)
            throw new InvalidOperationException($"Checked-in count cannot exceed current capacity ({CurrentCapacity}).");
        CheckedInCount += count;
        MarkUpdated();
    }

    public void DecrementCheckedIn(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (CheckedInCount - count < 0)
            throw new InvalidOperationException("Checked-in count cannot go below zero.");
        CheckedInCount -= count;
        MarkUpdated();
    }

    public void CompleteCheckOut(int count = 1)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(count, nameof(count));
        if (CheckedInCount - count < 0)
            throw new InvalidOperationException("Checked-in count cannot go below zero.");
        if (CurrentCapacity - count < 0)
            throw new InvalidOperationException("Occupancy cannot go below zero.");
        CheckedInCount -= count;
        CurrentCapacity -= count;
        MarkUpdated();
    }

    public void ToggleActive(bool active)
    {
        IsActive = active;
        MarkUpdated();
    }

    public void ForceSoldOut()
    {
        IsActive = false;
        CurrentCapacity = MaxCapacity;
        MarkUpdated();
    }

    public void Reopen()
    {
        IsActive = true;
        CurrentCapacity = 0;
        CheckedInCount = 0;
        MarkUpdated();
    }

    public void AddAvailability(DayOfWeek dayOfWeek, TimeOnly opensAt, TimeOnly closesAt)
    {
        if (opensAt >= closesAt)
            throw new ArgumentException("Opening time must be before closing time.");
        if (_availability.Any(a => a.DayOfWeek == dayOfWeek))
            throw new InvalidOperationException($"Availability for {dayOfWeek} already exists.");
        _availability.Add(VenueAvailability.Create(dayOfWeek, opensAt, closesAt));
        MarkUpdated();
    }

    public void ActivatePriorityPing()
    {
        IsPriorityPingActive = true;
        PriorityPingExpiry = DateTimeOffset.UtcNow.AddDays(7);
        MarkUpdated();
    }

    public void DeactivatePriorityPing()
    {
        IsPriorityPingActive = false;
        PriorityPingExpiry = null;
        MarkUpdated();
    }
}

/// <summary>
/// Weekly opening-hours slice for a venue. Associated to Venue via FK.
/// </summary>
public sealed class VenueAvailability : BaseEntity
{
    public Guid VenueId { get; private set; }

    public DayOfWeek DayOfWeek { get; private set; }

    public TimeOnly OpensAt { get; private set; }

    public TimeOnly ClosesAt { get; private set; }

    private VenueAvailability()
    {
        // EF Core constructor.
    }

    public static VenueAvailability Create(DayOfWeek dayOfWeek, TimeOnly opensAt, TimeOnly closesAt)
    {
        if (opensAt >= closesAt)
            throw new ArgumentException("Opening time must be before closing time.");
        return new VenueAvailability
        {
            DayOfWeek = dayOfWeek,
            OpensAt = opensAt,
            ClosesAt = closesAt
        };
    }
}