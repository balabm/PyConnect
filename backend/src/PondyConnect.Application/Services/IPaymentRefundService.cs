namespace PondyConnect.Application.Services;

/// <summary>
/// Issues an automatic refund to the consumer when a checkout succeeds at the
/// payment provider but fails to persist in the application database.
/// </summary>
public interface IPaymentRefundService
{
    /// <summary>
    /// Refunds the specified amount for the given provider payment id.
    /// Returns <c>true</c> when the refund is accepted by the provider.
    /// </summary>
    Task<bool> RefundAsync(string paymentId, decimal amount, string reason, CancellationToken ct);
}
