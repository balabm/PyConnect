namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Services;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

/// <summary>
/// RazorpayX payout service implementation. Calls the RazorpayX API
/// to send bank/UPI payouts to vendors and drivers.
///
/// NOTE: This is inactive in development — the mock implementation
/// is registered instead. In production, this is activated when
/// real Razorpay keys are configured.
/// </summary>
public sealed class RazorpayPayoutService : IPayoutService
{
    private readonly HttpClient _httpClient;
    private readonly RazorpayOptions _options;
    private readonly ILogger<RazorpayPayoutService> _logger;

    private const string BaseUrl = "https://api.razorpay.com/v1/";

    public RazorpayPayoutService(HttpClient httpClient, IOptions<RazorpayOptions> options, ILogger<RazorpayPayoutService> logger)
    {
        _httpClient = httpClient;
        _options = options.Value;
        _logger = logger;

        var credentials = Convert.ToBase64String(
            System.Text.Encoding.UTF8.GetBytes($"{_options.KeyId}:{_options.KeySecret}"));
        _httpClient.BaseAddress = new Uri(BaseUrl);
        _httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Basic", credentials);
    }

    public async Task<PayoutResult> SendBankPayoutAsync(
        decimal amount,
        string bankAccountNumber,
        string ifsc,
        string? accountHolderName,
        string? purpose = null,
        CancellationToken ct = default)
    {
        try
        {
            var payload = new
            {
                account_number = bankAccountNumber,
                ifsc = ifsc,
                name = accountHolderName,
                amount = (int)(amount * 100), // paise
                currency = "INR",
                purpose = purpose ?? "payout",
                mode = "IMPS"
            };

            var response = await _httpClient.PostAsJsonAsync("payouts", payload, ct);
            var body = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("RazorpayX bank payout failed: {Status} {Body}", response.StatusCode, body);
                return new PayoutResult(false, null, null, $"RazorpayX error: {response.StatusCode}");
            }

            var result = JsonDocument.Parse(body);
            var payoutId = result.RootElement.GetProperty("id").GetString();
            var utr = result.RootElement.TryGetProperty("utrz", out var utrEl) ? utrEl.GetString() : null;

            return new PayoutResult(true, payoutId, utr, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RazorpayX bank payout exception");
            return new PayoutResult(false, null, null, ex.Message);
        }
    }

    public async Task<PayoutResult> SendUpiPayoutAsync(
        decimal amount,
        string upiId,
        string? purpose = null,
        CancellationToken ct = default)
    {
        try
        {
            var payload = new
            {
                vpa = upiId,
                amount = (int)(amount * 100),
                currency = "INR",
                purpose = purpose ?? "payout",
                mode = "UPI"
            };

            var response = await _httpClient.PostAsJsonAsync("payouts", payload, ct);
            var body = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
            {
                _logger.LogError("RazorpayX UPI payout failed: {Status} {Body}", response.StatusCode, body);
                return new PayoutResult(false, null, null, $"RazorpayX error: {response.StatusCode}");
            }

            var result = JsonDocument.Parse(body);
            var payoutId = result.RootElement.GetProperty("id").GetString();
            var utr = result.RootElement.TryGetProperty("utrz", out var utrEl) ? utrEl.GetString() : null;

            return new PayoutResult(true, payoutId, utr, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RazorpayX UPI payout exception");
            return new PayoutResult(false, null, null, ex.Message);
        }
    }

    public async Task<PayoutStatusResult> GetPayoutStatusAsync(string providerPayoutId, CancellationToken ct = default)
    {
        try
        {
            var response = await _httpClient.GetAsync($"payouts/{providerPayoutId}", ct);
            var body = await response.Content.ReadAsStringAsync(ct);

            if (!response.IsSuccessStatusCode)
                return new PayoutStatusResult("failed", null, $"HTTP {response.StatusCode}");

            var result = JsonDocument.Parse(body);
            var status = result.RootElement.GetProperty("status").GetString() ?? "unknown";
            var utr = result.RootElement.TryGetProperty("utrz", out var utrEl) ? utrEl.GetString() : null;

            return new PayoutStatusResult(status, utr, null);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "RazorpayX status check exception");
            return new PayoutStatusResult("failed", null, ex.Message);
        }
    }
}
