namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Tracks an active dine-in session at a table.
/// When a customer scans the QR code again, this session is detected
/// so additional items can be grouped under the existing KDS ticket
/// instead of creating a brand-new unprioritized order.
/// </summary>
public sealed class DineInSession : BaseEntity
{
    /// <summary>
    /// The venue (restaurant) where the table is located.
    /// </summary>
    public Guid VenueId { get; private set; }

    /// <summary>
    /// The vendor (kitchen) that fulfills orders from this table.
    /// </summary>
    public Guid VendorId { get; private set; }

    /// <summary>
    /// The physical table number printed on the QR code sticker.
    /// </summary>
    public int TableId { get; private set; }

    /// <summary>
    /// The customer who opened the session by scanning the QR code.
    /// Additional customers may join by scanning the same QR code.
    /// </summary>
    public Guid OpenedByUserId { get; private set; }

    /// <summary>
    /// The first order associated with this session.
    /// Subsequent "add to order" requests are linked to this order's KDS ticket.
    /// </summary>
    public Guid? RootOrderId { get; private set; }

    /// <summary>
    /// Session status: Active, Closed, or Abandoned.
    /// </summary>
    public DineInSessionStatus Status { get; private set; } = DineInSessionStatus.Active;

    /// <summary>
    /// When the session was opened (QR scan time).
    /// </summary>
    public DateTimeOffset OpenedAt { get; private set; }

    /// <summary>
    /// When the session was closed (bill settled or table cleared).
    /// </summary>
    public DateTimeOffset? ClosedAt { get; private set; }

    /// <summary>
    /// Total amount settled across all orders in this session.
    /// </summary>
    public decimal TotalSettled { get; private set; }

    public static DineInSession Create(
        Guid venueId,
        Guid vendorId,
        int tableId,
        Guid openedByUserId)
    {
        if (venueId == Guid.Empty)
            throw new ArgumentException("Venue ID is required.", nameof(venueId));
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentOutOfRangeException.ThrowIfLessThanOrEqual(tableId, 0, nameof(tableId));
        if (openedByUserId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(openedByUserId));

        return new DineInSession
        {
            VenueId = venueId,
            VendorId = vendorId,
            TableId = tableId,
            OpenedByUserId = openedByUserId,
            OpenedAt = DateTimeOffset.UtcNow
        };
    }

    /// <summary>
    /// Links the first food order to this session as the root KDS ticket.
    /// </summary>
    public void AttachRootOrder(Guid orderId)
    {
        if (orderId == Guid.Empty)
            throw new ArgumentException("Order ID is required.", nameof(orderId));
        if (RootOrderId.HasValue)
            throw new InvalidOperationException("Session already has a root order.");

        RootOrderId = orderId;
        MarkUpdated();
    }

    /// <summary>
    /// Adds a settled amount to the session total (called when an order is paid).
    /// </summary>
    public void AddSettledAmount(decimal amount)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(amount, nameof(amount));
        TotalSettled += amount;
        MarkUpdated();
    }

    /// <summary>
    /// Closes the session when the bill is settled or the table is cleared.
    /// </summary>
    public void Close()
    {
        if (Status == DineInSessionStatus.Closed)
            return;

        Status = DineInSessionStatus.Closed;
        ClosedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the session as abandoned (e.g., customer left without paying).
    /// </summary>
    public void Abandon()
    {
        if (Status == DineInSessionStatus.Closed)
            return;

        Status = DineInSessionStatus.Abandoned;
        ClosedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public bool IsActive => Status == DineInSessionStatus.Active;
}
