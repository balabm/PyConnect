namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Sends outbound WhatsApp messages via the Meta Graph API using the
/// pre-registered <see cref="WhatsAppHttpClient"/>. When credentials are
/// not configured, messages are logged to the console for local development.
/// </summary>
public sealed class WhatsAppMessageSender : IWhatsAppSender
{
    private static readonly Action<ILogger, string, string, Exception?> s_sendOk =
        LoggerMessage.Define<string, string>(
            LogLevel.Information,
            new EventId(10, "WhatsAppSent"),
            "[WhatsApp -> {Phone}] {Message}");

    private static readonly Action<ILogger, string, Exception?> s_sendFail =
        LoggerMessage.Define<string>(
            LogLevel.Warning,
            new EventId(11, "WhatsAppSendFailed"),
            "WhatsApp message to {Phone} failed; booking flow continues.");

    private readonly WhatsAppHttpClient _httpClient;
    private readonly ILogger<WhatsAppMessageSender> _logger;

    public WhatsAppMessageSender(WhatsAppHttpClient httpClient, ILogger<WhatsAppMessageSender> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
    }

    public async Task SendBookingConfirmationAsync(
        string userPhone,
        string serviceType,
        string qrToken,
        CancellationToken cancellationToken = default)
    {
        var message =
            $"✅ *PondyConnect Booking Confirmed*\n\n" +
            $"*Service:* {serviceType}\n" +
            $"*Pass Token:* {qrToken}\n\n" +
            $"Show this token at entry. Have a great time in Pondicherry! 🏖️";

        try
        {
            var success = await _httpClient.SendTextMessageAsync(userPhone, message, cancellationToken);
            if (success)
                s_sendOk(_logger, userPhone, message, null);
            else
                s_sendFail(_logger, userPhone, null);
        }
        catch (Exception ex)
        {
            s_sendFail(_logger, userPhone, ex);
        }
    }
}
