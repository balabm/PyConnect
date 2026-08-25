namespace PondyConnect.Application.Common.Interfaces;

using PondyConnect.Domain.Enums;

public interface IPaymentGateway
{
    /// <summary>
    /// Creates a payment order with the provider. When <paramref name="capture"/>
    /// is false, the payment is only authorized (auth-hold) and must be
    /// captured later via <see cref="CapturePaymentAsync"/>. Used for
    /// security deposit holds on equipment rentals.
    /// </summary>
    Task<PaymentOrderResult> CreateOrderAsync(
        decimal amount,
        string currency,
        string receiptId,
        bool capture = true,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Captures a previously authorized (uncaptured) payment. Used to
    /// collect damage penalties from a security deposit auth-hold.
    /// </summary>
    Task<CaptureResult> CapturePaymentAsync(
        string providerPaymentId,
        decimal amount,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Releases an uncaptured authorization, returning the held funds
    /// to the customer. Used when a security deposit is refunded with
    /// no damage penalties.
    /// </summary>
    Task<ReleaseResult> ReleasePaymentAsync(
        string providerPaymentId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Verifies a webhook payload from the provider.
    /// </summary>
    Task<PaymentVerificationResult> VerifyWebhookAsync(
        string payload,
        string signature,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Verifies a client-side payment signature (Razorpay checkout).
    /// The signature is an HMAC-SHA256 of <c>order_id|payment_id</c> keyed
    /// by the provider key secret.
    /// </summary>
    Task<bool> VerifyPaymentSignatureAsync(
        string razorpayOrderId,
        string razorpayPaymentId,
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

    /// <summary>
    /// Fetches the current status of a provider order from the Razorpay API.
    /// Used by the payment reconciliation worker to recover orders where the
    /// user paid but the app lost network before confirming.
    /// </summary>
    Task<ProviderOrderStatusResult> FetchOrderStatusAsync(
        string providerOrderId,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Sends a payout to a linked bank account or UPI via RazorpayX.
    /// Returns a placeholder if the payout service is not configured.
    /// </summary>
    Task<PayoutResult> PayoutAsync(
        decimal amount,
        string? bankAccountNumber,
        string? upiId,
        string? purpose,
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
    string? ErrorMessage = null,
    string? EventId = null,
    string? EventType = null);

public sealed record RefundResult(
    bool Success,
    string? RefundId = null,
    string? ErrorMessage = null);

/// <summary>
/// Result of fetching an order's status from the payment provider.
/// AmountPaid is in rupees (converted from paise by the gateway).
/// </summary>
public sealed record ProviderOrderStatusResult(
    bool Success,
    string? ProviderOrderId = null,
    string? ProviderPaymentId = null,
    PaymentStatus Status = PaymentStatus.Unpaid,
    decimal AmountPaid = 0m,
    string? ErrorMessage = null);

public sealed record PayoutResult(
    bool Success,
    string? PayoutId = null,
    string? Utr = null,
    string? ErrorMessage = null);

public sealed record CaptureResult(
    bool Success,
    string? ErrorMessage = null);

public sealed record ReleaseResult(
    bool Success,
    string? ErrorMessage = null);