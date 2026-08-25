namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A ticket purchased for a P2P event. Carries a unique PassToken that
/// is encoded as a QR code and validated by the host's scanner at the
/// door. Reuses the same QR validation infrastructure as ServiceBooking.
/// </summary>
public sealed class P2pEventTicket : BaseEntity
{
    public Guid P2pEventId { get; private set; }

    public Guid BuyerUserId { get; private set; }

    public decimal PricePaid { get; private set; }

    public decimal PlatformFee { get; private set; }

    public decimal HostPayout { get; private set; }

    public PaymentStatus PaymentStatus { get; private set; } = PaymentStatus.Unpaid;

    public string? PaymentReference { get; private set; }

    /// <summary>
    /// Unique QR token used for scanner validation.
    /// </summary>
    public string? PassToken { get; private set; }

    /// <summary>
    /// Active = purchased and not yet checked in.
    /// CheckedIn = guest has been scanned at the door.
    /// Refunded = ticket cancelled and refunded.
    /// </summary>
    public string Status { get; private set; } = "Active";

    public DateTimeOffset? CheckedInAt { get; private set; }

    public DateTimeOffset PurchasedAt { get; private set; } = DateTimeOffset.UtcNow;

    private P2pEventTicket()
    {
        // EF Core constructor.
    }

    public static P2pEventTicket Create(
        Guid p2pEventId,
        Guid buyerUserId,
        decimal pricePaid,
        decimal platformFeePercent)
    {
        if (p2pEventId == Guid.Empty)
            throw new ArgumentException("Event ID is required.", nameof(p2pEventId));
        if (buyerUserId == Guid.Empty)
            throw new ArgumentException("Buyer user ID is required.", nameof(buyerUserId));
        ArgumentOutOfRangeException.ThrowIfNegative(pricePaid, nameof(pricePaid));
        ArgumentOutOfRangeException.ThrowIfNegative(platformFeePercent, nameof(platformFeePercent));

        var platformFee = pricePaid * platformFeePercent / 100m;
        var hostPayout = pricePaid - platformFee;

        return new P2pEventTicket
        {
            P2pEventId = p2pEventId,
            BuyerUserId = buyerUserId,
            PricePaid = pricePaid,
            PlatformFee = platformFee,
            HostPayout = hostPayout,
            PurchasedAt = DateTimeOffset.UtcNow
        };
    }

    public void IssuePassToken(string token)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(token);
        PassToken = token;
        MarkUpdated();
    }

    public void RecordPayment(PaymentStatus paymentStatus, string paymentReference)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(paymentReference);
        PaymentStatus = paymentStatus;
        PaymentReference = paymentReference;
        MarkUpdated();
    }

    public void CheckIn()
    {
        if (Status == "CheckedIn")
            throw new InvalidOperationException("Ticket has already been checked in.");
        if (Status == "Refunded")
            throw new InvalidOperationException("Cannot check in a refunded ticket.");
        Status = "CheckedIn";
        CheckedInAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Refund()
    {
        if (Status == "CheckedIn")
            throw new InvalidOperationException("Cannot refund a checked-in ticket.");
        Status = "Refunded";
        MarkUpdated();
    }
}
