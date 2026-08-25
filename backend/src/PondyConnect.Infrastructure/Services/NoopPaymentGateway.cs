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
        bool capture = true,
        CancellationToken cancellationToken = default)
    {
        var orderId = $"order_noop_{Guid.NewGuid():N}";
        return Task.FromResult(new PaymentOrderResult(
            Success: true,
            OrderId: orderId,
            ShortUrl: $"https://dev.pay/noop/{orderId}"));
    }

    public Task<CaptureResult> CapturePaymentAsync(
        string providerPaymentId,
        decimal amount,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(new CaptureResult(Success: true));
    }

    public Task<ReleaseResult> ReleasePaymentAsync(
        string providerPaymentId,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(new ReleaseResult(Success: true));
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

    public Task<PayoutResult> PayoutAsync(
        decimal amount,
        string? bankAccountNumber,
        string? upiId,
        string? purpose,
        CancellationToken cancellationToken = default)
    {
        return Task.FromResult(new PayoutResult(
            Success: true,
            PayoutId: $"payout_noop_{Guid.NewGuid():N}",
            Utr: $"UTR{Guid.NewGuid():N}",
            ErrorMessage: "No-op payout simulated."));
    }

    public Task<ProviderOrderStatusResult> FetchOrderStatusAsync(
        string providerOrderId,
        CancellationToken cancellationToken = default)
    {
        // In dev mode, simulate a paid order so the reconciliation worker
        // picks it up and transitions the booking to confirmed.
        return Task.FromResult(new ProviderOrderStatusResult(
            Success: true,
            ProviderOrderId: providerOrderId,
            ProviderPaymentId: $"pay_noop_{Guid.NewGuid():N}",
            Status: PaymentStatus.Captured));
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