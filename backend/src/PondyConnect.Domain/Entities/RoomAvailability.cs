namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

public sealed class RoomAvailability : BaseEntity
{
    public Guid HomestayId { get; private set; }

    public DateOnly Date { get; private set; }

    public bool IsBooked { get; private set; }

    public Guid? LockedByBookingId { get; private set; }

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
        MarkUpdated();
    }

    public void Unlock()
    {
        IsBooked = false;
        LockedByBookingId = null;
        MarkUpdated();
    }
}
