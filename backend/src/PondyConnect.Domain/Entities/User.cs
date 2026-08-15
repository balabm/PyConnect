namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A user of the PondyConnect super-app. Single source of truth for both
/// tourists (service consumers) and locals (consumers &amp; vendors).
/// </summary>
public sealed class User : BaseEntity
{
    public string Name { get; private set; } = string.Empty;

    public string Phone { get; private set; } = string.Empty;

    public UserRole Role { get; private set; } = UserRole.Tourist;

    public bool IsActive { get; private set; } = true;

    public bool IsProMember { get; private set; }

    public DateTimeOffset? ProMemberUntil { get; private set; }

    public bool IsVerifiedLocal { get; private set; }

    public string? AadhaarHash { get; private set; }

    public DateTimeOffset? VerifiedAt { get; private set; }

    public bool HasAcceptedLiabilityWaiver { get; private set; }

    public DateTimeOffset? WaiverAcceptedAt { get; private set; }

    public string? DrivingLicenseNumber { get; private set; }

    public KycVerificationStatus KycVerificationStatus { get; private set; } = KycVerificationStatus.Pending;

    public DateTimeOffset? LastLoginAt { get; private set; }

    public string? FcmDeviceToken { get; private set; }

    public string? GoogleId { get; private set; }

    public string? Email { get; private set; }

    public bool IsEmailVerified { get; private set; }

    public string? PictureUrl { get; private set; }

    /// <summary>
    /// Dietary preference: "veg", "non_veg", "vegan", "egg", or null (no preference).
    /// Used to personalize restaurant and food sorting.
    /// </summary>
    public string? DietaryPreference { get; private set; }

    /// <summary>Whether the user has completed the first-launch onboarding flow.</summary>
    public bool HasCompletedOnboarding { get; private set; }

    private User()
    {
        // EF Core constructor.
    }

    public static User Create(string name, string phone, UserRole role = UserRole.Tourist)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(phone);
        if (phone.Length < 10)
            throw new ArgumentException("Phone number must be at least 10 digits.", nameof(phone));

        return new User { Name = name, Phone = phone, Role = role };
    }

    public void UpdateProfile(string name)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        Name = name;
        MarkUpdated();
    }

    public void ChangeRole(UserRole role)
    {
        Role = role;
        MarkUpdated();
    }

    public void RecordLogin()
    {
        LastLoginAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkUpdated();
    }

    public void Activate()
    {
        IsActive = true;
        MarkUpdated();
    }

    public void RejectKyc()
    {
        KycVerificationStatus = KycVerificationStatus.Rejected;
        MarkUpdated();
    }

    public void ActivateProMembership(int durationDays)
    {
        IsProMember = true;
        ProMemberUntil = DateTimeOffset.UtcNow.AddDays(durationDays);
        MarkUpdated();
    }

    public void DeactivateProMembership()
    {
        IsProMember = false;
        ProMemberUntil = null;
        MarkUpdated();
    }

    public void VerifyAsLocal(string aadhaarHash)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(aadhaarHash);
        IsVerifiedLocal = true;
        AadhaarHash = aadhaarHash;
        VerifiedAt = DateTimeOffset.UtcNow;
        if (Role == UserRole.Tourist)
            Role = UserRole.Local;
        MarkUpdated();
    }

    public void AcceptLiabilityWaiver()
    {
        HasAcceptedLiabilityWaiver = true;
        WaiverAcceptedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void SetDrivingLicense(string dlNumber)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(dlNumber);
        DrivingLicenseNumber = dlNumber;
        MarkUpdated();
    }

    public void UpdateKycStatus(KycVerificationStatus status)
    {
        KycVerificationStatus = status;
        MarkUpdated();
    }

    public void UpdateFcmDeviceToken(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        FcmDeviceToken = token;
        MarkUpdated();
    }

    public void LinkGoogle(string googleId, string email, bool isEmailVerified, string? pictureUrl)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(googleId);
        ArgumentException.ThrowIfNullOrWhiteSpace(email);

        GoogleId = googleId;
        Email = email;
        IsEmailVerified = isEmailVerified;
        PictureUrl = pictureUrl;
        MarkUpdated();
    }

    public void UpdateNameFromGoogle(string name)
    {
        if (!string.IsNullOrWhiteSpace(name) && string.IsNullOrWhiteSpace(Name))
            Name = name;
    }

    /// <summary>
    /// Sets the user's dietary preference for food personalization.
    /// Valid values: "veg", "non_veg", "vegan", "egg".
    /// </summary>
    public void UpdateDietaryPreference(string? preference)
    {
        DietaryPreference = preference;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the first-launch onboarding flow as complete.
    /// </summary>
    public void CompleteOnboarding()
    {
        HasCompletedOnboarding = true;
        MarkUpdated();
    }
}