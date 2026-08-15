namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// An individual driver for the ride-hailing module. Separate from Vendor
/// because drivers are individuals, not businesses.
/// </summary>
public sealed class Driver : BaseEntity
{
    public Guid UserId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string Phone { get; private set; } = string.Empty;

    public VehicleType VehicleType { get; private set; }

    public string? VehiclePlate { get; private set; }

    public bool IsOnline { get; private set; }

    public bool IsApproved { get; private set; }

    public GeoLocation CurrentLocation { get; private set; } = GeoLocation.Zero;

    public double Rating { get; private set; } = 5.0;

    public int TotalRides { get; private set; }

    public int TotalRatings { get; private set; }

    public double AcceptanceRate { get; private set; } = 1.0;

    public int TotalOffers { get; private set; }

    public int TotalAccepted { get; private set; }

    public double CancellationRate { get; private set; }

    public int TotalCancellations { get; private set; }

    public bool IsOnRide { get; private set; }

    public Guid? CurrentRideId { get; private set; }

    public DateTimeOffset? LastLocationAt { get; private set; }

    public string? AadhaarUrl { get; private set; }

    public string? DrivingLicenseUrl { get; private set; }

    public string? RcUrl { get; private set; }

    public string? UpiId { get; private set; }

    public bool IsKycUploaded { get; private set; }

    public string? EmergencyContactName { get; private set; }

    public string? EmergencyContactPhone { get; private set; }

    /// <summary>Storage key for the vehicle insurance document.</summary>
    public string? InsuranceUrl { get; private set; }

    /// <summary>Storage key for the driver selfie photo.</summary>
    public string? SelfieUrl { get; private set; }

    /// <summary>Whether the driver has completed the mandatory safety tutorial.</summary>
    public bool HasCompletedTutorial { get; private set; }

    /// <summary>Whether the driver has signed the digital safety agreement.</summary>
    public bool HasSignedAgreement { get; private set; }

    /// <summary>When the tutorial was completed.</summary>
    public DateTimeOffset? TutorialCompletedAt { get; private set; }

    private Driver()
    {
    }

    public static Driver Create(
        Guid userId,
        string name,
        string phone,
        VehicleType vehicleType,
        string? vehiclePlate = null)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(phone);

        return new Driver
        {
            UserId = userId,
            Name = name,
            Phone = phone,
            VehicleType = vehicleType,
            VehiclePlate = vehiclePlate
        };
    }

    public static Driver CreateForSeed(
        Guid id,
        Guid userId,
        string name,
        string phone,
        VehicleType vehicleType,
        string? vehiclePlate = null,
        bool isApproved = true)
    {
        var driver = Create(userId, name, phone, vehicleType, vehiclePlate);
        driver.SetExplicitId(id);
        driver.IsApproved = isApproved;
        return driver;
    }

    public void Approve()
    {
        IsApproved = true;
        MarkUpdated();
    }

    public void GoOnline()
    {
        if (IsOnRide)
            throw new InvalidOperationException("Cannot go online while on an active ride.");
        IsOnline = true;
        MarkUpdated();
    }

    public void GoOffline()
    {
        if (IsOnRide)
            throw new InvalidOperationException("Cannot go offline while on an active ride.");
        IsOnline = false;
        MarkUpdated();
    }

    public void UpdateLocation(GeoLocation location)
    {
        CurrentLocation = location;
        LastLocationAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void StartRide(Guid rideId)
    {
        if (IsOnRide)
            throw new InvalidOperationException("Driver is already on a ride.");
        IsOnRide = true;
        CurrentRideId = rideId;
        MarkUpdated();
    }

    public void EndRide()
    {
        if (!IsOnRide)
            return;
        IsOnRide = false;
        CurrentRideId = null;
        TotalRides++;
        MarkUpdated();
    }

    public void RecordRideCompleted()
    {
        TotalRides++;
        MarkUpdated();
    }

    /// <summary>
    /// Record whether the driver accepted or declined a ride offer.
    /// Updates the acceptance rate for dispatch scoring.
    /// </summary>
    public void RecordOfferResult(bool accepted)
    {
        TotalOffers++;
        if (accepted) TotalAccepted++;
        AcceptanceRate = (double)TotalAccepted / TotalOffers;
        MarkUpdated();
    }

    /// <summary>
    /// Record a driver cancellation (post-assignment). Impacts cancellation rate
    /// for dispatch eligibility scoring.
    /// </summary>
    public void RecordCancellation()
    {
        TotalCancellations++;
        CancellationRate = TotalRides > 0
            ? (double)TotalCancellations / (TotalRides + TotalCancellations)
            : (double)TotalCancellations / TotalCancellations;
        MarkUpdated();
    }

    /// <summary>
    /// Update the driver's rating after a rider submits a rating.
    /// Uses weighted running average.
    /// </summary>
    public void UpdateRating(int newRating)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(newRating, 1, nameof(newRating));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(newRating, 5, nameof(newRating));

        TotalRatings++;
        Rating = ((Rating * (TotalRatings - 1)) + newRating) / TotalRatings;
        MarkUpdated();
    }

    public void UploadKyc(string aadhaarUrl, string drivingLicenseUrl, string rcUrl, string upiId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(aadhaarUrl);
        ArgumentException.ThrowIfNullOrWhiteSpace(drivingLicenseUrl);
        ArgumentException.ThrowIfNullOrWhiteSpace(rcUrl);
        ArgumentException.ThrowIfNullOrWhiteSpace(upiId);

        AadhaarUrl = aadhaarUrl;
        DrivingLicenseUrl = drivingLicenseUrl;
        RcUrl = rcUrl;
        UpiId = upiId;
        IsKycUploaded = true;
        MarkUpdated();
    }

    public void SetEmergencyContact(string name, string phone)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(phone);
        EmergencyContactName = name;
        EmergencyContactPhone = phone;
        MarkUpdated();
    }

    /// <summary>
    /// Uploads extended KYC documents including insurance and selfie,
    /// supplementing the base KYC (Aadhaar, DL, RC).
    /// </summary>
    public void UploadExtendedKyc(string? insuranceUrl, string? selfieUrl)
    {
        InsuranceUrl = insuranceUrl ?? InsuranceUrl;
        SelfieUrl = selfieUrl ?? SelfieUrl;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the mandatory safety tutorial as completed.
    /// The driver cannot accept rides until this is done.
    /// </summary>
    public void CompleteTutorial()
    {
        HasCompletedTutorial = true;
        TutorialCompletedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Records the driver's digital signature on the safety agreement.
    /// </summary>
    public void SignAgreement()
    {
        HasSignedAgreement = true;
        MarkUpdated();
    }
}
