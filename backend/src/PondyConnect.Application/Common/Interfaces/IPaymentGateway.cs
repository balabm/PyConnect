namespace PondyConnect.Application.Common.Interfaces;

using PondyConnect.Domain.Enums;

public interface IPaymentGateway
{
    /// <summary>
    /// Creates a payment order with the provider.
    /// </summary>
    Task<PaymentOrderResult> CreateOrderAsync(
        decimal amount,
        string currency,
        string receiptId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Verifies a webhook payload from the provider.
    /// </summary>
    Task<PaymentVerificationResult> VerifyWebhookAsync(
        string payload,
        string signature,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Refunds a captured payment.
    /// </summary>
    Task<RefundResult> RefundAsync(
        string providerPaymentId,
        decimal amount,
        string reason,
        CancellationToken cancellationToken = default);
}

public sealed record PaymentOrderResult(
    bool Success,
    string? OrderId = null,
    string? ShortUrl = null,
    string? ErrorMessage = null);

public sealed record PaymentVerificationResult(
    bool IsValid,
    string? ProviderPaymentId = null,
    string? ProviderOrderId = null,
    PaymentStatus Status = PaymentStatus.Failed,
    string? ErrorMessage = null);

public sealed record RefundResult(
    bool Success,
    string? RefundId = null,
    string? ErrorMessage = null);