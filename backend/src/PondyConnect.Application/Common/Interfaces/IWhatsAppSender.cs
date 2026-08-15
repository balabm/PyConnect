namespace PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Sends outbound WhatsApp messages via the Meta Graph API.
/// Used for booking confirmations, pass delivery, and post-checkout notifications.
/// </summary>
public interface IWhatsAppSender
{
    /// <summary>
    /// Sends a booking confirmation message with a QR/pass token to the user's WhatsApp.
    /// Fire-and-forget — failures are logged but do not block the calling flow.
    /// </summary>
    /// <param name="userPhone">Recipient phone in international format (e.g. 919876543210).</param>
    /// <param name="serviceType">Human-readable service name (e.g. "VIP Pub Pass", "Scooter Rental").</param>
    /// <param name="qrToken">The pass/QR token to display at entry.</param>
    /// <param name="cancellationToken">Cancellation token.</param>
    Task SendBookingConfirmationAsync(
        string userPhone,
        string serviceType,
        string qrToken,
        CancellationToken cancellationToken = default);
}
