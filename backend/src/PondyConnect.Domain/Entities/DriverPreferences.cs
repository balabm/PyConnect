namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Per-driver shift preferences that control dispatch behavior.
/// Includes destination mode (only accept rides heading toward a target
/// location) and service type toggles (opt in/out of food, rides, luggage).
/// </summary>
public sealed class DriverPreferences : BaseEntity
{
    public Guid DriverId { get; private set; }

    // ── Destination Mode ──

    /// <summary>
    /// Whether destination mode is active. When active, the dispatch engine
    /// only assigns rides whose drop-off is geometrically closer to the
    /// target destination than the driver's current location.
    /// </summary>
    public bool DestinationModeEnabled { get; private set; }

    /// <summary>Destination latitude (null when disabled).</summary>
    public double? DestinationLatitude { get; private set; }

    /// <summary>Destination longitude (null when disabled).</summary>
    public double? DestinationLongitude { get; private set; }

    /// <summary>
    /// Human-readable label for the destination (e.g., "Auroville").
    /// </summary>
    public string? DestinationLabel { get; private set; }

    // ── Service Type Toggles ──

    public bool AcceptFoodDelivery { get; private set; } = true;
    public bool AcceptRides { get; private set; } = true;
    public bool AcceptIntercity { get; private set; } = true;
    public bool AcceptLuggageTransport { get; private set; } = true;
    public bool AcceptEssentials { get; private set; } // Quick Essentials module disabled — defaults to false

    private DriverPreferences() { }

    public static DriverPreferences Create(Guid driverId)
    {
        return new DriverPreferences
        {
            DriverId = driverId,
            DestinationModeEnabled = false,
            AcceptFoodDelivery = true,
            AcceptRides = true,
            AcceptIntercity = true,
            AcceptLuggageTransport = true,
            // AcceptEssentials defaults to false — Quick Essentials module disabled
        };
    }

    public void SetDestination(GeoLocation? destination, string? label)
    {
        DestinationLatitude = destination?.Latitude;
        DestinationLongitude = destination?.Longitude;
        DestinationLabel = label;
        DestinationModeEnabled = destination is not null;
        MarkUpdated();
    }

    public void ClearDestination()
    {
        DestinationLatitude = null;
        DestinationLongitude = null;
        DestinationLabel = null;
        DestinationModeEnabled = false;
        MarkUpdated();
    }

    public void UpdateServiceToggles(
        bool? foodDelivery = null,
        bool? rides = null,
        bool? intercity = null,
        bool? luggage = null,
        bool? essentials = null)
    {
        if (foodDelivery.HasValue) AcceptFoodDelivery = foodDelivery.Value;
        if (rides.HasValue) AcceptRides = rides.Value;
        if (intercity.HasValue) AcceptIntercity = intercity.Value;
        if (luggage.HasValue) AcceptLuggageTransport = luggage.Value;
        if (essentials.HasValue) AcceptEssentials = essentials.Value;
        MarkUpdated();
    }
}
