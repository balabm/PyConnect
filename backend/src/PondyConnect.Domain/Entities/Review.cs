namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A user-submitted rating (and optional tip) for a completed ride,
/// food order, or venue experience. One review per user per target.
/// </summary>
public class Review : BaseEntity
{
    public Guid UserId { get; private set; }       // The reviewer
    public Guid? DriverId { get; private set; }     // Target driver (for ride reviews)
    public Guid? VendorId { get; private set; }     // Target vendor (for food/venue reviews)
    public Guid? RideId { get; private set; }       // Associated ride
    public Guid? OrderId { get; private set; }      // Associated food order
    public int Rating { get; private set; }         // 1-5 stars
    public string? Feedback { get; private set; }   // Optional text
    public decimal? TipAmount { get; private set; } // Optional tip
    public string? TipReference { get; private set; } // Razorpay reference

    /// <summary>Owner's public reply to this review (vendor or driver).</summary>
    public string? OwnerReply { get; private set; }

    /// <summary>When the owner submitted their reply.</summary>
    public DateTimeOffset? OwnerReplyedAt { get; private set; }

    private Review() { }

    public static Review Create(
        Guid userId, int rating, string? feedback = null,
        decimal? tipAmount = null, Guid? driverId = null,
        Guid? vendorId = null, Guid? rideId = null, Guid? orderId = null)
    {
        if (rating < 1 || rating > 5) throw new ArgumentOutOfRangeException(nameof(rating));
        return new Review
        {
            UserId = userId,
            DriverId = driverId,
            VendorId = vendorId,
            RideId = rideId,
            OrderId = orderId,
            Rating = rating,
            Feedback = feedback,
            TipAmount = tipAmount,
        };
    }

    /// <summary>
    /// Sets the owner's public reply to this review. Only one reply
    /// is allowed per review; calling this again overwrites the previous reply.
    /// </summary>
    public void SetOwnerReply(string reply)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(reply);
        if (reply.Length > 1000)
            throw new ArgumentException("Reply must be under 1000 characters.", nameof(reply));
        OwnerReply = reply;
        OwnerReplyedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}
