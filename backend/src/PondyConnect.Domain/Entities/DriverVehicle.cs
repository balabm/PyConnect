namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A vehicle registered by a driver. Drivers can own multiple vehicles
/// (e.g., a bike for food delivery and an auto for rides). Only one
/// vehicle can be active at a time — the active vehicle determines the
/// dispatch queue the driver is enrolled in.
/// </summary>
public sealed class DriverVehicle : BaseEntity
{
    public Guid DriverId { get; private set; }

    public VehicleType VehicleType { get; private set; }

    public string RegistrationNumber { get; private set; } = string.Empty;

    public string? Color { get; private set; }

    public string? Model { get; private set; }

    /// <summary>
    /// Storage URL for the RC (Registration Certificate) book photo.
    /// </summary>
    public string? RcBookUrl { get; private set; }

    /// <summary>
    /// Storage URL for the insurance document.
    /// </summary>
    public string? InsuranceUrl { get; private set; }

    /// <summary>
    /// Insurance expiry date. Used by the compliance service to push
    /// renewal reminders.
    /// </summary>
    public DateTime? InsuranceExpiryDate { get; private set; }

    /// <summary>
    /// Whether this vehicle is approved by admin. New vehicles go into
    /// pending state until an admin reviews the RC book.
    /// </summary>
    public bool IsApproved { get; private set; }

    /// <summary>
    /// Whether this is the driver's currently active vehicle. Only one
    /// vehicle per driver can be active at a time.
    /// </summary>
    public bool IsActive { get; private set; }

    /// <summary>
    /// Admin review notes (e.g., rejection reason).
    /// </summary>
    public string? ReviewNotes { get; private set; }

    private DriverVehicle() { }

    public static DriverVehicle Create(
        Guid driverId,
        VehicleType vehicleType,
        string registrationNumber,
        string? color = null,
        string? model = null,
        string? rcBookUrl = null,
        string? insuranceUrl = null,
        DateTime? insuranceExpiryDate = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(registrationNumber);

        return new DriverVehicle
        {
            DriverId = driverId,
            VehicleType = vehicleType,
            RegistrationNumber = registrationNumber.ToUpperInvariant(),
            Color = color,
            Model = model,
            RcBookUrl = rcBookUrl,
            InsuranceUrl = insuranceUrl,
            InsuranceExpiryDate = insuranceExpiryDate,
            IsApproved = false,
            IsActive = false,
        };
    }

    public void Approve(string? notes = null)
    {
        IsApproved = true;
        ReviewNotes = notes;
        MarkUpdated();
    }

    public void Reject(string reason)
    {
        IsApproved = false;
        ReviewNotes = reason;
        MarkUpdated();
    }

    public void Activate()
    {
        IsActive = true;
        MarkUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkUpdated();
    }

    public void UpdateInsurance(string? insuranceUrl, DateTime? expiryDate)
    {
        InsuranceUrl = insuranceUrl ?? InsuranceUrl;
        InsuranceExpiryDate = expiryDate ?? InsuranceExpiryDate;
        MarkUpdated();
    }

    public void UpdateRcBook(string rcBookUrl)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(rcBookUrl);
        RcBookUrl = rcBookUrl;
        MarkUpdated();
    }
}
