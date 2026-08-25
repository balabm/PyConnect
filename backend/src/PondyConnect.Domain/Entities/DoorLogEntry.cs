namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A manual door-log entry created by Pub/Club bouncers when a guest
/// walks in without a digital ticket. Keeps the live occupancy count
/// accurate and provides an audit trail for cash/VIP entries.
/// </summary>
public sealed class DoorLogEntry : BaseEntity
{
    public Guid VenueId { get; private set; }

    public Guid VendorId { get; private set; }

    /// <summary>
    /// "Male", "Female", or "Couple".
    /// </summary>
    public string GuestType { get; private set; } = string.Empty;

    /// <summary>
    /// "Cash" or "VIP" (VIP = free entry).
    /// </summary>
    public string EntryType { get; private set; } = "Cash";

    /// <summary>
    /// Number of people in this entry (1 for Male/Female, 2 for Couple).
    /// </summary>
    public int Headcount { get; private set; } = 1;

    /// <summary>
    /// Cover charge collected at the door (0 for VIP/free).
    /// </summary>
    public decimal CoverCollected { get; private set; }

    public string? Notes { get; private set; }

    public DateTimeOffset EnteredAt { get; private set; } = DateTimeOffset.UtcNow;

    private DoorLogEntry() { }

    public static DoorLogEntry Create(
        Guid venueId,
        Guid vendorId,
        string guestType,
        string entryType,
        int headcount,
        decimal coverCollected = 0,
        string? notes = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(guestType);
        ArgumentException.ThrowIfNullOrWhiteSpace(entryType);

        if (venueId == Guid.Empty)
            throw new ArgumentException("Venue ID is required.", nameof(venueId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        if (headcount <= 0)
            throw new ArgumentOutOfRangeException(nameof(headcount), "Headcount must be positive.");
        if (coverCollected < 0)
            throw new ArgumentOutOfRangeException(nameof(coverCollected), "Cover cannot be negative.");

        return new DoorLogEntry
        {
            VenueId = venueId,
            VendorId = vendorId,
            GuestType = guestType,
            EntryType = entryType,
            Headcount = headcount,
            CoverCollected = coverCollected,
            Notes = notes
        };
    }
}
