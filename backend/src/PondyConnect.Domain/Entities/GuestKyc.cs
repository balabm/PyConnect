namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Digital check-in KYC documents for a homestay/rental booking. Per
/// Pondicherry police regulations, hotels and vehicle rentals must
/// collect guest IDs. Instead of photocopying at the front desk, the
/// consumer uploads their Govt ID via the app before arrival.
///
/// The documents are stored in a private S3 bucket and can ONLY be
/// viewed by the Partner during the 24-hour check-in window. A
/// background worker deletes the S3 objects 48 hours after checkout
/// to protect user privacy (DPDP Act compliance).
/// </summary>
public sealed class GuestKyc : BaseEntity
{
    public Guid BookingId { get; private set; }

    public Guid UserId { get; private set; }

    /// <summary>
    /// S3 object key for the front side of the Govt ID (Aadhaar/Passport).
    /// Stored in the private bucket — accessed via presigned URL only.
    /// </summary>
    public string? IdFrontUrl { get; private set; }

    /// <summary>
    /// S3 object key for the back side of the Govt ID.
    /// </summary>
    public string? IdBackUrl { get; private set; }

    /// <summary>
    /// The type of ID uploaded (Aadhaar, Passport, Driving License, etc.)
    /// </summary>
    public string? IdType { get; private set; }

    /// <summary>
    /// Whether the KYC documents have been uploaded and verified.
    /// The QR pass token is blocked until this is true.
    /// </summary>
    public bool IsUploaded { get; private set; }

    public DateTimeOffset? UploadedAt { get; private set; }

    /// <summary>
    /// Whether the partner/host has viewed the KYC documents.
    /// </summary>
    public bool IsViewedByPartner { get; private set; }

    public DateTimeOffset? ViewedByPartnerAt { get; private set; }

    private GuestKyc() { }

    public static GuestKyc Create(Guid bookingId, Guid userId)
    {
        if (bookingId == Guid.Empty)
            throw new ArgumentException("Booking ID is required.", nameof(bookingId));
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));

        return new GuestKyc
        {
            BookingId = bookingId,
            UserId = userId,
            IsUploaded = false
        };
    }

    /// <summary>
    /// Records the uploaded ID document URLs and marks the KYC as
    /// uploaded. Called after the consumer uploads front/back photos
    /// to S3 via the digital check-in screen.
    /// </summary>
    public void MarkUploaded(string idFrontUrl, string? idBackUrl, string idType)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(idFrontUrl);
        ArgumentException.ThrowIfNullOrWhiteSpace(idType);

        IdFrontUrl = idFrontUrl;
        IdBackUrl = idBackUrl;
        IdType = idType;
        IsUploaded = true;
        UploadedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Marks the KYC as viewed by the partner/host. Used for audit
    /// logging and to track when the host checked the guest's ID.
    /// </summary>
    public void MarkViewedByPartner()
    {
        IsViewedByPartner = true;
        ViewedByPartnerAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}
