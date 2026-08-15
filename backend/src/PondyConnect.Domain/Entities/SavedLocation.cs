namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A saved location for a user (Home, Work, etc.) for quick ride booking.
/// </summary>
public sealed class SavedLocation
{
    public Guid Id { get; private set; }
    public Guid UserId { get; private set; }
    public string Label { get; private set; } = string.Empty;
    public string Address { get; private set; } = string.Empty;
    public GeoLocation Location { get; private set; } = null!;
    public DateTimeOffset CreatedAt { get; private set; }

    private SavedLocation() { }

    public static SavedLocation Create(Guid userId, string label, string address, GeoLocation location)
    {
        if (string.IsNullOrWhiteSpace(label))
            throw new ArgumentException("Label is required.", nameof(label));
        if (string.IsNullOrWhiteSpace(address))
            throw new ArgumentException("Address is required.", nameof(address));
        if (label.Length > 50)
            throw new ArgumentException("Label must be 50 characters or fewer.", nameof(label));
        if (address.Length > 300)
            throw new ArgumentException("Address must be 300 characters or fewer.", nameof(address));

        return new SavedLocation
        {
            Id = Guid.NewGuid(),
            UserId = userId,
            Label = label,
            Address = address,
            Location = location ?? throw new ArgumentNullException(nameof(location)),
            CreatedAt = DateTimeOffset.UtcNow
        };
    }

    public void Update(string label, string address, GeoLocation location)
    {
        if (string.IsNullOrWhiteSpace(label))
            throw new ArgumentException("Label is required.", nameof(label));
        if (string.IsNullOrWhiteSpace(address))
            throw new ArgumentException("Address is required.", nameof(address));

        Label = label;
        Address = address;
        Location = location ?? throw new ArgumentNullException(nameof(location));
    }
}
