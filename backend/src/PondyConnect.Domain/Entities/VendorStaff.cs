namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A staff member invited by a vendor to use the Partner app with
/// restricted permissions. The staff member logs in via OTP using
/// their mobile number, and the JWT role claim is set to "VendorStaff"
/// with a specific <see cref="StaffRole"/> that the Flutter router
/// uses to lock down navigation.
/// </summary>
public sealed class VendorStaff : BaseEntity
{
    public Guid VendorId { get; private set; }

    /// <summary>
    /// Staff member's mobile number (used for OTP login).
    /// </summary>
    public string Phone { get; private set; } = string.Empty;

    /// <summary>
    /// Display name of the staff member.
    /// </summary>
    public string Name { get; private set; } = string.Empty;

    /// <summary>
    /// "Bouncer", "KitchenStaff", or "Manager".
    /// </summary>
    public string Role { get; private set; } = string.Empty;

    public bool IsActive { get; private set; } = true;

    private VendorStaff() { }

    public static VendorStaff Create(
        Guid vendorId,
        string phone,
        string name,
        string role)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(phone);
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(role);

        if (phone.Length < 10)
            throw new ArgumentException("Phone number must be at least 10 digits.", nameof(phone));

        var validRoles = new[] { "Bouncer", "KitchenStaff", "Manager" };
        if (!validRoles.Contains(role))
            throw new ArgumentException($"Role must be one of: {string.Join(", ", validRoles)}", nameof(role));

        return new VendorStaff
        {
            VendorId = vendorId,
            Phone = phone,
            Name = name,
            Role = role,
            IsActive = true
        };
    }

    public void Deactivate()
    {
        IsActive = false;
        MarkUpdated();
    }

    public void Reactivate()
    {
        IsActive = true;
        MarkUpdated();
    }

    public void UpdateRole(string newRole)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(newRole);
        var validRoles = new[] { "Bouncer", "KitchenStaff", "Manager" };
        if (!validRoles.Contains(newRole))
            throw new ArgumentException($"Role must be one of: {string.Join(", ", validRoles)}", nameof(newRole));
        Role = newRole;
        MarkUpdated();
    }
}
