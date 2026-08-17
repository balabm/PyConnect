namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Logging;
using PondyConnect.Application.Services;

/// <summary>
/// Razorpay refund adapter used by the distributed-transaction safety net.
/// Delegates to the concrete <see cref="RazorpayGateway"/> so unconfigured
/// environments fall back gracefully to a logged failure instead of crashing.
/// </summary>
public sealed class PaymentRefundService : IPaymentRefundService
{
    private readonly RazorpayGateway _gateway;
    private readonly ILogger<PaymentRefundService> _logger;

    public PaymentRefundService(RazorpayGateway gateway, ILogger<PaymentRefundService> logger)
    {
        _gateway = gateway;
        _logger = logger;
    }

    public async Task<bool> RefundAsync(string paymentId, decimal amount, string reason, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(paymentId))
        {
            _logger.LogWarning("Refund requested with an empty payment id.");
            return false;
        }

        _logger.LogCritical(
            "CRITICAL_AUTO_REFUND: Refunding payment {PaymentId} amount {Amount} for {Reason}",
            paymentId,
            amount,
            reason);

        var result = await _gateway.RefundAsync(paymentId, amount, reason, ct);
        if (!result.Success)
        {
            _logger.LogError(
                "CRITICAL_AUTO_REFUND: Refund failed for payment {PaymentId}: {Error}",
                paymentId,
                result.ErrorMessage);
            return false;
        }

        _logger.LogInformation(
            "CRITICAL_AUTO_REFUND: Refund succeeded for payment {PaymentId}: {RefundId}",
            paymentId,
            result.RefundId);
        return true;
    }
}
