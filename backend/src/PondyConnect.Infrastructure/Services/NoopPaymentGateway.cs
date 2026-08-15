namespace PondyConnect.Infrastructure.Services;

using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// No-op payment gateway for local development without Razorpay keys.
/// Simulates instant capture.
/// </summary>
public sealed class NoopPaymentGateway : IPaymentGateway
{
    public Task<PaymentOrderResult> CreateOrderAsync(
        decimal amount,
        string currency,
        string receiptId,
        CancellationToken cancellationToken = default)
    {
        var orderId = $"order_noop_{Guid.NewGuid():N}";
        return Task.FromResult(new PaymentOrderResult(
            Success: true,
            OrderId: orderId,
            ShortUrl: $"https://dev.pay/noop/{orderId}"));
    }

    public Task<PaymentVerificationResult> VerifyWebhookAsync(
        string payload,
        string signature,
        CancellationToken cancellationToken = default)
    {
        // In dev mode, always treat as valid captured payment
        return Task.FromResult(new PaymentVerificationResult(
            IsValid: true,
            ProviderPaymentId: $"pay_noop_{Guid.NewGuid():N}",
            ProviderOrderId: ExtractOrderId(payload),
            Status: PaymentStatus.Captured));
    }

    public Task<bool> VerifyPaymentSignatureAsync(
        string razorpayOrderId,
        string razorpayPaymentId,
        string signature,
        CancellationToken cancellationToken = default)
    {
        // In dev mode, always treat as valid
        return Task.FromResult(true);
    }

    public Task<RefundResult> RefundAsync(
        string providerPaymentId,
        decimal amount,
        string reason,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(new RefundResult(
            Success: true,
            RefundId: $"refund_noop_{Guid.NewGuid():N}"));
    }

    private static string? ExtractOrderId(string payload)
    {
        // Very loose extraction for dev
        try
        {
            using var doc = System.Text.Json.JsonDocument.Parse(payload);
            if (doc.RootElement.TryGetProperty("order_id", out var oid))
                return oid.GetString();
        }
        catch { }
        return null;
    }
}