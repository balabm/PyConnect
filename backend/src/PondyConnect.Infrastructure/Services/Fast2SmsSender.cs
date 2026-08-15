namespace PondyConnect.Infrastructure.Services;

using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;

/// <summary>
/// Fast2SMS production SMS gateway implementation.
/// Uses the Quick SMS / DLTS OTP route for time-sensitive OTP delivery.
/// Requires "Sms:ApiKey" in configuration.
/// </summary>
public sealed class Fast2SmsSender : ISmsSender
{
    private static readonly Action<ILogger, string, string, Exception?> s_sendOk =
        LoggerMessage.Define<string, string>(
            LogLevel.Information,
            new EventId(1, "SmsSent"),
            "[SMS -> {Phone}] {Message}");

    private static readonly Action<ILogger, string, int, Exception?> s_sendFail =
        LoggerMessage.Define<string, int>(
            LogLevel.Error,
            new EventId(2, "SmsSendFailed"),
            "Fast2SMS delivery to {Phone} failed with status {StatusCode}");

    private static readonly Action<ILogger, string, Exception?> s_sendError =
        LoggerMessage.Define<string>(
            LogLevel.Error,
            new EventId(3, "SmsSendError"),
            "Fast2SMS delivery to {Phone} threw an exception");

    private readonly HttpClient _http;
    private readonly ILogger<Fast2SmsSender> _logger;
    private readonly string _apiKey;
    private readonly string _senderId;

    public Fast2SmsSender(HttpClient http, IConfiguration configuration, ILogger<Fast2SmsSender> logger)
    {
        _http = http;
        _logger = logger;
        _apiKey = configuration["Sms:ApiKey"]
            ?? throw new InvalidOperationException("Sms:ApiKey is not configured for Fast2SMS.");
        _senderId = configuration["Sms:SenderId"] ?? "PNDYC";

        _http.BaseAddress = new Uri("https://www.fast2sms.com/");
        _http.Timeout = TimeSpan.FromSeconds(10);
        _http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(_apiKey);
    }

    public async Task SendAsync(string phone, string message, CancellationToken cancellationToken = default)
    {
        // Fast2SMS expects the Indian number without country code
        var cleanPhone = phone.TrimStart('+');
        if (cleanPhone.StartsWith("91", StringComparison.Ordinal) && cleanPhone.Length > 10)
            cleanPhone = cleanPhone[2..];

        var payload = new
        {
            sender_id = _senderId,
            message = message,
            language = "english",
            route = "otp",
            numbers = cleanPhone,
        };

        try
        {
            var response = await _http.PostAsJsonAsync("/dev/bulkV2", payload, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
                s_sendFail(_logger, phone, (int)response.StatusCode, null);
                throw new SmsDeliveryException(phone, $"HTTP {(int)response.StatusCode}: {body}", (int)response.StatusCode);
            }

            s_sendOk(_logger, phone, message, null);
        }
        catch (SmsDeliveryException)
        {
            throw;
        }
        catch (Exception ex)
        {
            s_sendError(_logger, phone, ex);
            throw new SmsDeliveryException(phone, ex.Message, inner: ex);
        }
    }
}
