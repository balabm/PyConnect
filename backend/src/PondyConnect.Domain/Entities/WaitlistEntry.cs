namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Pre-launch waitlist entry captured via QR-code scan at partner locations.
/// When a waitlisted phone number subsequently registers via OTP, the entry
/// is marked <see cref="IsConverted"/> and the user receives promo credits.
/// </summary>
public sealed class WaitlistEntry : BaseEntity
{
    public string PhoneNumber { get; private set; } = string.Empty;

    public string? SourceQrCodeLocation { get; private set; }

    public bool IsConverted { get; private set; }

    public DateTimeOffset? ConvertedAt { get; private set; }

    private WaitlistEntry()
    {
    }

    public static WaitlistEntry Create(string phoneNumber, string? sourceQrCodeLocation = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(phoneNumber);
        if (phoneNumber.Length < 10)
            throw new ArgumentException("Phone number must be at least 10 digits.", nameof(phoneNumber));

        return new WaitlistEntry
        {
            PhoneNumber = phoneNumber,
            SourceQrCodeLocation = sourceQrCodeLocation
        };
    }

    public void MarkConverted()
    {
        if (IsConverted)
            return;
        IsConverted = true;
        ConvertedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}
