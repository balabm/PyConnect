namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A transit node (bus stand, airport, railway station) used for pickup/drop scheduling.
/// </summary>
public sealed class TransitHub : BaseEntity
{
    public string Name { get; private set; } = string.Empty;

    public string? Address { get; private set; }

    public TransitHubKind Kind { get; private set; }

    public GeoLocation Location { get; private set; } = GeoLocation.Zero;

    public bool IsActive { get; private set; } = true;

    private TransitHub()
    {
        // EF Core constructor.
    }

    public static TransitHub Create(
        string name,
        TransitHubKind kind,
        GeoLocation location,
        string? address = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        return new TransitHub
        {
            Name = name,
            Kind = kind,
            Location = location,
            Address = address
        };
    }

    public void UpdateDetails(string name, string? address)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        Name = name;
        Address = address;
        MarkUpdated();
    }

    public void ToggleActive(bool active)
    {
        IsActive = active;
        MarkUpdated();
    }
}