namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A saved user address (Home, Work, Other) with detailed location fields
/// for delivery and ride-hailing flows.
/// </summary>
public sealed class UserAddress : BaseEntity
{
    public Guid UserId { get; private set; }

    public string? DoorFlat { get; private set; }

    public string? Landmark { get; private set; }

    public string Tag { get; private set; } = string.Empty;

    public string FormattedAddress { get; private set; } = string.Empty;

    public GeoLocation Location { get; private set; } = null!;

    private UserAddress()
    {
        // EF Core constructor.
    }

    public static UserAddress Create(
        Guid userId,
        string? doorFlat,
        string? landmark,
        string tag,
        string formattedAddress,
        GeoLocation location)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(tag);
        ArgumentException.ThrowIfNullOrWhiteSpace(formattedAddress);

        if (tag != "Home" && tag != "Work" && tag != "Other")
            throw new ArgumentException("Tag must be Home, Work, or Other.", nameof(tag));

        return new UserAddress
        {
            UserId = userId,
            DoorFlat = doorFlat,
            Landmark = landmark,
            Tag = tag,
            FormattedAddress = formattedAddress,
            Location = location ?? throw new ArgumentNullException(nameof(location))
        };
    }

    public void Update(
        string? doorFlat,
        string? landmark,
        string tag,
        string formattedAddress,
        GeoLocation location)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(tag);
        ArgumentException.ThrowIfNullOrWhiteSpace(formattedAddress);

        if (tag != "Home" && tag != "Work" && tag != "Other")
            throw new ArgumentException("Tag must be Home, Work, or Other.", nameof(tag));

        DoorFlat = doorFlat;
        Landmark = landmark;
        Tag = tag;
        FormattedAddress = formattedAddress;
        Location = location ?? throw new ArgumentNullException(nameof(location));
        MarkUpdated();
    }
}
