namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

public sealed class Homestay : BaseEntity
{
    public Guid HostId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string Description { get; private set; } = string.Empty;

    public string LocationArea { get; private set; } = string.Empty;

    public double Latitude { get; private set; }

    public double Longitude { get; private set; }

    public decimal NightlyRate { get; private set; }

    public int MaxGuests { get; private set; }

    public bool HasWifi { get; private set; }

    public bool IsVerified { get; private set; }

    private Homestay()
    {
    }

    public static Homestay Create(
        Guid hostId,
        string name,
        string description,
        string locationArea,
        double latitude,
        double longitude,
        decimal nightlyRate,
        int maxGuests,
        bool hasWifi = false)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(description);
        ArgumentException.ThrowIfNullOrWhiteSpace(locationArea);
        ArgumentOutOfRangeException.ThrowIfNegative(nightlyRate, nameof(nightlyRate));
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(maxGuests, 0, nameof(maxGuests));

        return new Homestay
        {
            HostId = hostId,
            Name = name,
            Description = description,
            LocationArea = locationArea,
            Latitude = latitude,
            Longitude = longitude,
            NightlyRate = nightlyRate,
            MaxGuests = maxGuests,
            HasWifi = hasWifi,
            IsVerified = false
        };
    }

    public void UpdateDetails(
        string name,
        string description,
        string locationArea,
        double latitude,
        double longitude,
        decimal nightlyRate,
        int maxGuests,
        bool hasWifi)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(description);
        ArgumentException.ThrowIfNullOrWhiteSpace(locationArea);
        ArgumentOutOfRangeException.ThrowIfNegative(nightlyRate, nameof(nightlyRate));
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(maxGuests, 0, nameof(maxGuests));

        Name = name;
        Description = description;
        LocationArea = locationArea;
        Latitude = latitude;
        Longitude = longitude;
        NightlyRate = nightlyRate;
        MaxGuests = maxGuests;
        HasWifi = hasWifi;
        MarkUpdated();
    }

    public void Verify()
    {
        IsVerified = true;
        MarkUpdated();
    }
}
