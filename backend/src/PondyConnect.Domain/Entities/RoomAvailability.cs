namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

public sealed class RoomAvailability : BaseEntity
{
    public Guid HomestayId { get; private set; }

    public DateOnly Date { get; private set; }

    public bool IsBooked { get; private set; }

    public Guid? LockedByBookingId { get; private set; }

    /// <summary>
    /// Temporary pending lock placed when a user selects dates but has
    /// not yet paid. Prevents double-booking during the payment flow.
    /// Expires after 10 minutes. A background worker releases expired
    /// locks back to the public pool.
    /// </summary>
    public DateTimeOffset? PendingLockUntil { get; private set; }

    /// <summary>
    /// The user who holds the pending lock (not the booking ID, since
    /// the booking hasn't been created yet).
    /// </summary>
    public Guid? PendingLockedByUserId { get; private set; }

    private RoomAvailability()
    {
    }

    public static RoomAvailability Create(Guid homestayId, DateOnly date)
    {
        return new RoomAvailability
        {
            HomestayId = homestayId,
            Date = date,
            IsBooked = false,
            LockedByBookingId = null
        };
    }

    public void Lock(Guid bookingId)
    {
        if (IsBooked)
            throw new InvalidOperationException("Date is already booked.");

        IsBooked = true;
        LockedByBookingId = bookingId;
        PendingLockUntil = null;
        PendingLockedByUserId = null;
        MarkUpdated();
    }

    public void Unlock()
    {
        IsBooked = false;
        LockedByBookingId = null;
        PendingLockUntil = null;
        PendingLockedByUserId = null;
        MarkUpdated();
    }

    /// <summary>
    /// Places a temporary pending lock on this date for 10 minutes.
    /// Prevents double-booking while the user completes payment.
    /// If the date is already booked or has an active pending lock
    /// held by a different user, throws BookingConflictException.
    /// </summary>
    public void PlacePendingLock(Guid userId, TimeSpan lockDuration)
    {
        if (IsBooked)
            throw new InvalidOperationException("Date is already booked.");

        // Check if there's an active pending lock from a different user.
        if (PendingLockUntil is not null && PendingLockUntil > DateTimeOffset.UtcNow
            && PendingLockedByUserId != userId)
        {
            throw new InvalidOperationException("Date is temporarily held by another user. Please try again shortly.");
        }

        // If the existing lock belongs to this user, refresh it.
        // If the lock has expired, clear it and place a new one.
        PendingLockUntil = DateTimeOffset.UtcNow.Add(lockDuration);
        PendingLockedByUserId = userId;
        MarkUpdated();
    }

    /// <summary>
    /// Releases a pending lock. Called when the user navigates away
    /// from the booking screen without paying, or when the lock
    /// expires.
    /// </summary>
    public void ReleasePendingLock(Guid userId)
    {
        if (PendingLockedByUserId == userId)
        {
            PendingLockUntil = null;
            PendingLockedByUserId = null;
            MarkUpdated();
        }
    }

    /// <summary>
    /// Clears an expired pending lock. Called by a background worker
    /// that runs periodically to release stale locks back to the
    /// public pool.
    /// </summary>
    public void ClearExpiredPendingLock()
    {
        if (PendingLockUntil is not null && PendingLockUntil <= DateTimeOffset.UtcNow && !IsBooked)
        {
            PendingLockUntil = null;
            PendingLockedByUserId = null;
            MarkUpdated();
        }
    }

    /// <summary>
    /// Whether this date currently has an active (non-expired) pending
    /// lock that would prevent another user from booking it.
    /// </summary>
    public bool HasActivePendingLock =>
        PendingLockUntil is not null && PendingLockUntil > DateTimeOffset.UtcNow && !IsBooked;
}

