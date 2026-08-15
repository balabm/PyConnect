namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A rider's emergency contact, notified on SOS trigger with live trip link.
/// </summary>
public sealed class EmergencyContact : BaseEntity
{
    public Guid UserId { get; private set; }

    public string Name { get; private set; } = string.Empty;

    public string Phone { get; private set; } = string.Empty;

    public string? Relationship { get; private set; }

    private EmergencyContact()
    {
    }

    public static EmergencyContact Create(Guid userId, string name, string phone, string? relationship = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(name);
        ArgumentException.ThrowIfNullOrWhiteSpace(phone);

        return new EmergencyContact
        {
            UserId = userId,
            Name = name,
            Phone = phone,
            Relationship = relationship
        };
    }
}
