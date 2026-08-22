namespace PondyConnect.Application.Services;

/// <summary>
/// Abstraction for vendor/driver payout execution. Production uses
/// RazorpayX; development and tests use the mock implementation.
/// </summary>
public interface IPayoutService
{
    /// <summary>
    /// Sends a payout to a bank account via RazorpayX.
    /// Returns the provider payout ID on success.
    /// </summary>
    Task<PayoutResult> SendBankPayoutAsync(
        decimal amount,
        string bankAccountNumber,
        string ifsc,
        string? accountHolderName,
        string? purpose = null,
        CancellationToken ct = default);

    /// <summary>
    /// Sends a payout to a UPI ID via RazorpayX.
    /// </summary>
    Task<PayoutResult> SendUpiPayoutAsync(
        decimal amount,
        string upiId,
        string? purpose = null,
        CancellationToken ct = default);

    /// <summary>
    /// Fetches the current status of a payout from the provider.
    /// </summary>
    Task<PayoutStatusResult> GetPayoutStatusAsync(string providerPayoutId, CancellationToken ct = default);
}

public sealed record PayoutResult(
    bool Success,
    string? ProviderPayoutId,
    string? UtrNumber,
    string? FailureReason);

public sealed record PayoutStatusResult(
    string Status, // "processed", "pending", "reversed", "failed"
    string? UtrNumber,
    string? FailureReason);
