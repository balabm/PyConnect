namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A scooter or bike in a vendor's rental fleet. Vendors manage their
/// inventory (add, update, remove scooters) and set availability,
/// pricing, and vehicle details.
/// </summary>
public sealed class ScooterFleetItem : BaseEntity
{
    public Guid VendorId { get; private set; }

    public string Model { get; private set; } = string.Empty;

    public string? PlateNumber { get; private set; }

    /// <summary>
    /// Hourly rental rate in INR.
    /// </summary>
    public decimal RatePerHour { get; private set; }

    /// <summary>
    /// Daily rental rate in INR (optional — for full-day rentals).
    /// </summary>
    public decimal? RatePerDay { get; private set; }

    /// <summary>
    /// Whether the scooter is currently available for rental.
    /// </summary>
    public bool IsAvailable { get; private set; } = true;

    /// <summary>
    /// Whether the scooter is currently rented out.
    /// </summary>
    public bool IsRented { get; private set; }

    public string? ImageUrl { get; private set; }

    /// <summary>
    /// Battery percentage (0-100) for electric scooters. Null for petrol.
    /// </summary>
    public int? BatteryPercent { get; private set; }

    /// <summary>
    /// Whether this is an electric vehicle.
    /// </summary>
    public bool IsElectric { get; private set; }

    /// <summary>
    /// Current odometer reading in kilometers.
    /// </summary>
    public int? OdometerKm { get; private set; }

    /// <summary>
    /// Notes about the vehicle condition or maintenance status.
    /// </summary>
    public string? Notes { get; private set; }

    private ScooterFleetItem() { }

    public static ScooterFleetItem Create(
        Guid vendorId,
        string model,
        decimal ratePerHour,
        string? plateNumber = null,
        decimal? ratePerDay = null,
        bool isElectric = false,
        string? imageUrl = null,
        int? batteryPercent = null,
        int? odometerKm = null,
        string? notes = null)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(model);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(ratePerHour, nameof(ratePerHour));

        return new ScooterFleetItem
        {
            VendorId = vendorId,
            Model = model,
            RatePerHour = ratePerHour,
            PlateNumber = plateNumber,
            RatePerDay = ratePerDay,
            IsElectric = isElectric,
            ImageUrl = imageUrl,
            BatteryPercent = batteryPercent,
            OdometerKm = odometerKm,
            Notes = notes,
            IsAvailable = true,
            IsRented = false,
        };
    }

    public void Update(
        string? model = null,
        decimal? ratePerHour = null,
        decimal? ratePerDay = null,
        string? plateNumber = null,
        string? imageUrl = null,
        int? batteryPercent = null,
        int? odometerKm = null,
        string? notes = null,
        bool? isAvailable = null)
    {
        if (!string.IsNullOrWhiteSpace(model)) Model = model;
        if (ratePerHour is not null && ratePerHour.Value > 0m) RatePerHour = ratePerHour.Value;
        if (ratePerDay is not null) RatePerDay = ratePerDay.Value;
        if (plateNumber is not null) PlateNumber = plateNumber;
        if (imageUrl is not null) ImageUrl = imageUrl;
        if (batteryPercent is not null) BatteryPercent = batteryPercent;
        if (odometerKm is not null) OdometerKm = odometerKm;
        if (notes is not null) Notes = notes;
        if (isAvailable is not null) IsAvailable = isAvailable.Value;
        MarkUpdated();
    }

    public void MarkRented() { IsRented = true; IsAvailable = false; MarkUpdated(); }
    public void MarkReturned() { IsRented = false; IsAvailable = true; MarkUpdated(); }
    public void SetUnavailable() { IsAvailable = false; MarkUpdated(); }
    public void SetAvailable() { IsAvailable = true; MarkUpdated(); }
}
