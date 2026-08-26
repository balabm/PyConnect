namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A guest list entry for a pub/club venue. Vendors manage their guestlist
/// from the Partner app, and entries can be checked in at the door.
/// </summary>
public sealed class GuestlistEntry : BaseEntity
{
    public Guid VendorId { get; private set; }

    public string GuestName { get; private set; } = string.Empty;

    public int PartySize { get; private set; } = 1;

    public string? Phone { get; private set; }

    /// <summary>
    /// Whether the guest has been checked in at the door.
    /// </summary>
    public bool CheckedIn { get; private set; }

    /// <summary>
    /// Optional event date for the guestlist entry. Defaults to today.
    /// </summary>
    public DateOnly EventDate { get; private set; }

    private GuestlistEntry() { }

    public static GuestlistEntry Create(
        Guid vendorId,
        string guestName,
        int partySize = 1,
        string? phone = null,
        DateOnly? eventDate = null)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(guestName);
        ArgumentOutOfRangeException.ThrowIfLessThan(partySize, 1, nameof(partySize));

        return new GuestlistEntry
        {
            VendorId = vendorId,
            GuestName = guestName,
            PartySize = partySize,
            Phone = phone,
            CheckedIn = false,
            EventDate = eventDate ?? DateOnly.FromDateTime(DateTimeOffset.UtcNow.Date),
        };
    }

    public void CheckIn() { CheckedIn = true; MarkUpdated(); }
    public void UndoCheckIn() { CheckedIn = false; MarkUpdated(); }
    public void UpdatePartySize(int size)
    {
        ArgumentOutOfRangeException.ThrowIfLessThan(size, 1);
        PartySize = size;
        MarkUpdated();
    }
}
