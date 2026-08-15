namespace PondyConnect.Infrastructure.Services;

using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Infrastructure.Configuration;

public sealed class WhatsAppHttpClient
{
    private readonly HttpClient _httpClient;
    private readonly WhatsAppOptions _options;
    private readonly ILogger<WhatsAppHttpClient> _logger;

    public WhatsAppHttpClient(
        HttpClient httpClient,
        IOptions<WhatsAppOptions> options,
        ILogger<WhatsAppHttpClient> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;
    }

    public bool VerifySignature(string requestBody, string? signatureHeader)
    {
        if (string.IsNullOrWhiteSpace(signatureHeader))
            return false;

        var signature = signatureHeader.StartsWith("sha256=", StringComparison.OrdinalIgnoreCase)
            ? signatureHeader["sha256=".Length..]
            : signatureHeader;

        var key = Encoding.UTF8.GetBytes(_options.AppSecret);
        var body = Encoding.UTF8.GetBytes(requestBody);

        using var hmac = new HMACSHA256(key);
        var expectedHash = hmac.ComputeHash(body);
        var expectedHex = Convert.ToHexString(expectedHash).ToLowerInvariant();

        return CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expectedHex),
            Encoding.UTF8.GetBytes(signature.ToLowerInvariant()));
    }

    public async Task<bool> SendTextMessageAsync(
        string toPhoneNumber,
        string text,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(_options.PhoneNumberId)
            || string.IsNullOrWhiteSpace(_options.AccessToken))
        {
#pragma warning disable CA1848
            _logger.LogInformation("[WhatsApp Mock] To: {Phone}, Message: {Text}", toPhoneNumber, text);
#pragma warning restore CA1848
            return true;
        }

        var payload = new
        {
            messaging_product = "whatsapp",
            to = toPhoneNumber,
            type = "text",
            text = new { body = text }
        };

        var json = JsonSerializer.Serialize(payload);
        var content = new StringContent(json, Encoding.UTF8, "application/json");

        var request = new HttpRequestMessage(HttpMethod.Post,
            $"{_options.PhoneNumberId}/messages")
        {
            Content = content
        };
        request.Headers.Authorization =
            new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", _options.AccessToken);

        try
        {
            var response = await _httpClient.SendAsync(request, cancellationToken);
            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(cancellationToken);
#pragma warning disable CA1848
                _logger.LogError("WhatsApp API error: {Status} {Body}", response.StatusCode, body);
#pragma warning restore CA1848
                return false;
            }
            return true;
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogError(ex, "Failed to send WhatsApp message to {Phone}", toPhoneNumber);
#pragma warning restore CA1848
            return false;
        }
    }
}
