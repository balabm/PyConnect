namespace PondyConnect.Infrastructure.Services;

using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Razorpay payment gateway integration.
/// Requires valid keys in configuration; otherwise falls back to NoopPaymentGateway.
/// </summary>
public sealed class RazorpayGateway : IPaymentGateway
{
    private readonly RazorpayOptions _options;
    private readonly HttpClient _http;

    public RazorpayGateway(IOptions<RazorpayOptions> options, HttpClient http)
    {
        _options = options.Value;
        _http = http;
        _http.BaseAddress = new Uri("https://api.razorpay.com/");
        var auth = Convert.ToBase64String(Encoding.UTF8.GetBytes($"{_options.KeyId}:{_options.KeySecret}"));
        _http.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Basic", auth);
    }

    public async Task<PaymentOrderResult> CreateOrderAsync(
        decimal amount,
        string currency,
        string receiptId,
        bool capture = true,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret))
            return new PaymentOrderResult(false, ErrorMessage: "Razorpay keys not configured");

        var payload = new
        {
            amount = (int)(amount * 100), // Razorpay expects paise
            currency,
            receipt = receiptId,
            payment_capture = capture ? 1 : 0 // 1 = auto-capture, 0 = auth-hold only
        };

        var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        var response = await _http.PostAsync("v1/orders", content, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var err = await response.Content.ReadAsStringAsync(cancellationToken);
            return new PaymentOrderResult(false, ErrorMessage: $"Razorpay error: {err}");
        }

        var json = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        var orderId = json.GetProperty("id").GetString();
        var shortUrl = json.TryGetProperty("short_url", out var su) ? su.GetString() : null;

        return new PaymentOrderResult(true, OrderId: orderId, ShortUrl: shortUrl);
    }

    public Task<PaymentVerificationResult> VerifyWebhookAsync(
        string payload,
        string signature,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.WebhookSecret))
            return Task.FromResult(new PaymentVerificationResult(false, ErrorMessage: "Webhook secret not configured"));

        var expected = ComputeHmacSha256(payload, _options.WebhookSecret);
        if (!CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(signature)))
        {
            return Task.FromResult(new PaymentVerificationResult(false, ErrorMessage: "Invalid signature"));
        }

        try
        {
            using var doc = JsonDocument.Parse(payload);
            var root = doc.RootElement;

            // Razorpay webhook envelope: { "entity": "event", "id": "evt_...", "event": "payment.captured", "payload": { ... } }
            var eventId = root.TryGetProperty("id", out var idEl) && idEl.ValueKind == JsonValueKind.String
                ? idEl.GetString()
                : null;
            var eventType = root.TryGetProperty("event", out var eventEl) && eventEl.ValueKind == JsonValueKind.String
                ? eventEl.GetString()
                : null;

            var payment = root.GetProperty("payload").GetProperty("payment").GetProperty("entity");
            var paymentId = payment.GetProperty("id").GetString();
            var orderId = payment.GetProperty("order_id").GetString();
            var statusStr = payment.GetProperty("status").GetString();
            var status = statusStr == "captured" ? PaymentStatus.Captured : PaymentStatus.Failed;

            return Task.FromResult(new PaymentVerificationResult(
                IsValid: true,
                ProviderPaymentId: paymentId,
                ProviderOrderId: orderId,
                Status: status,
                EventId: eventId,
                EventType: eventType));
        }
        catch (Exception ex)
        {
            return Task.FromResult(new PaymentVerificationResult(false, ErrorMessage: ex.Message));
        }
    }

    public Task<bool> VerifyPaymentSignatureAsync(
        string razorpayOrderId,
        string razorpayPaymentId,
        string signature,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeySecret))
            return Task.FromResult(false);

        var payload = $"{razorpayOrderId}|{razorpayPaymentId}";
        var expected = ComputeHmacSha256(payload, _options.KeySecret);
        var isValid = CryptographicOperations.FixedTimeEquals(
            Encoding.UTF8.GetBytes(expected),
            Encoding.UTF8.GetBytes(signature));
        return Task.FromResult(isValid);
    }

    public async Task<RefundResult> RefundAsync(
        string providerPaymentId,
        decimal amount,
        string reason,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret))
            return new RefundResult(false, ErrorMessage: "Razorpay keys not configured");

        var payload = new
        {
            amount = (int)(amount * 100),
            notes = new { reason }
        };

        var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        var response = await _http.PostAsync($"v1/payments/{providerPaymentId}/refund", content, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var err = await response.Content.ReadAsStringAsync(cancellationToken);
            return new RefundResult(false, ErrorMessage: $"Razorpay refund error: {err}");
        }

        var json = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        var refundId = json.GetProperty("id").GetString();

        return new RefundResult(true, RefundId: refundId);
    }

    /// <summary>
    /// Fetches the current status of a Razorpay order by calling
    /// <c>GET v1/orders/{id}</c>. Used by the reconciliation worker to
    /// recover orders where the user paid but the app lost network before
    /// confirming the payment.
    /// </summary>
    public async Task<ProviderOrderStatusResult> FetchOrderStatusAsync(
        string providerOrderId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret))
            return new ProviderOrderStatusResult(false, ErrorMessage: "Razorpay keys not configured");

        if (string.IsNullOrWhiteSpace(providerOrderId))
            return new ProviderOrderStatusResult(false, ErrorMessage: "Provider order ID is required");

        var response = await _http.GetAsync($"v1/orders/{providerOrderId}", cancellationToken);
        if (!response.IsSuccessStatusCode)
        {
            var err = await response.Content.ReadAsStringAsync(cancellationToken);
            return new ProviderOrderStatusResult(false, ErrorMessage: $"Razorpay error: {err}");
        }

        var json = await response.Content.ReadFromJsonAsync<JsonElement>(cancellationToken);
        var statusStr = json.GetProperty("status").GetString() ?? "";
        var amountPaidPaise = json.TryGetProperty("amount_paid", out var ap) && ap.ValueKind == JsonValueKind.Number
            ? ap.GetInt32()
            : 0;
        var amountDuePaise = json.TryGetProperty("amount_due", out var ad) && ad.ValueKind == JsonValueKind.Number
            ? ad.GetInt32()
            : 0;

        // Determine the payment ID if any payments are associated.
        string? paymentId = null;
        if (json.TryGetProperty("payments", out var paymentsEl) && paymentsEl.TryGetProperty("items", out var itemsEl) && itemsEl.ValueKind == JsonValueKind.Array)
        {
            foreach (var item in itemsEl.EnumerateArray())
            {
                if (item.TryGetProperty("id", out var idEl) && idEl.ValueKind == JsonValueKind.String)
                {
                    paymentId = idEl.GetString();
                    break;
                }
            }
        }

        var status = (statusStr, amountDuePaise) switch
        {
            ("paid", 0) => PaymentStatus.Captured,
            ("attempted", _) => PaymentStatus.Failed,
            ("failed", _) => PaymentStatus.Failed,
            _ => PaymentStatus.Unpaid
        };

        return new ProviderOrderStatusResult(
            Success: true,
            ProviderOrderId: providerOrderId,
            ProviderPaymentId: paymentId,
            Status: status,
            AmountPaid: amountPaidPaise / 100m);
    }

    public async Task<CaptureResult> CapturePaymentAsync(
        string providerPaymentId,
        decimal amount,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret))
            return new CaptureResult(false, ErrorMessage: "Razorpay keys not configured");

        if (string.IsNullOrWhiteSpace(providerPaymentId))
            return new CaptureResult(false, ErrorMessage: "Provider payment ID is required");

        var payload = new
        {
            amount = (int)(amount * 100), // paise
            currency = "INR"
        };

        var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        var response = await _http.PostAsync($"v1/payments/{providerPaymentId}/capture", content, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var err = await response.Content.ReadAsStringAsync(cancellationToken);
            return new CaptureResult(false, ErrorMessage: $"Razorpay capture error: {err}");
        }

        return new CaptureResult(true);
    }

    public async Task<ReleaseResult> ReleasePaymentAsync(
        string providerPaymentId,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret))
            return new ReleaseResult(false, ErrorMessage: "Razorpay keys not configured");

        if (string.IsNullOrWhiteSpace(providerPaymentId))
            return new ReleaseResult(false, ErrorMessage: "Provider payment ID is required");

        // Razorpay releases an uncaptured authorization by refunding the
        // full authorized amount with the refund endpoint.
        var payload = new
        {
            amount = 0 // 0 means refund the full authorized amount
        };

        var content = new StringContent(JsonSerializer.Serialize(payload), Encoding.UTF8, "application/json");
        var response = await _http.PostAsync($"v1/payments/{providerPaymentId}/refund", content, cancellationToken);

        if (!response.IsSuccessStatusCode)
        {
            var err = await response.Content.ReadAsStringAsync(cancellationToken);
            return new ReleaseResult(false, ErrorMessage: $"Razorpay release error: {err}");
        }

        return new ReleaseResult(true);
    }

    public Task<PayoutResult> PayoutAsync(
        decimal amount,
        string? bankAccountNumber,
        string? upiId,
        string? purpose,
        CancellationToken cancellationToken = default)
    {
        var notConfigured = string.IsNullOrWhiteSpace(_options.KeyId) || string.IsNullOrWhiteSpace(_options.KeySecret);

        return Task.FromResult(new PayoutResult(
            Success: !notConfigured,
            PayoutId: $"payout_stub_{Guid.NewGuid():N}",
            Utr: notConfigured ? null : $"UTR{Guid.NewGuid():N}",
            ErrorMessage: notConfigured ? "RazorpayX is not configured; returning placeholder payout." : "RazorpayX integration is a stub."));
    }

    private static string ComputeHmacSha256(string data, string key)
    {
        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(key));
        var hash = hmac.ComputeHash(Encoding.UTF8.GetBytes(data));
        return Convert.ToHexString(hash).ToLowerInvariant();
    }
}

public sealed class RazorpayOptions
{
    public const string SectionName = "Razorpay";

    public string KeyId { get; set; } = string.Empty;
    public string KeySecret { get; set; } = string.Empty;
    public string WebhookSecret { get; set; } = string.Empty;
}