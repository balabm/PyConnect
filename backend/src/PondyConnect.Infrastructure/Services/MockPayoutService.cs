namespace PondyConnect.Infrastructure.Services;

using Microsoft.Extensions.Logging;
using PondyConnect.Application.Services;

/// <summary>
/// Mock payout service for development and testing. Simulates
/// successful payouts with fake provider IDs and UTR numbers.
/// </summary>
public sealed class MockPayoutService : IPayoutService
{
    private readonly ILogger<MockPayoutService> _logger;
    private static int _counter = 1000;

    public MockPayoutService(ILogger<MockPayoutService> logger)
    {
        _logger = logger;
    }

    public Task<PayoutResult> SendBankPayoutAsync(
        decimal amount,
        string bankAccountNumber,
        string ifsc,
        string? accountHolderName,
        string? purpose = null,
        CancellationToken ct = default)
    {
        var payoutId = $"pout_mock_{Interlocked.Increment(ref _counter)}";
        var utr = $"UTR{DateTimeOffset.UtcNow:yyyyMMddHHmmss}{_counter:D6}";

        _logger.LogInformation("MOCK PAYOUT: ₹{Amount} to {Account} ({Ifsc}). PayoutId: {PayoutId}, UTR: {Utr}",
            amount, bankAccountNumber, ifsc, payoutId, utr);

        return Task.FromResult(new PayoutResult(
            Success: true,
            ProviderPayoutId: payoutId,
            UtrNumber: utr,
            FailureReason: null));
    }

    public Task<PayoutResult> SendUpiPayoutAsync(
        decimal amount,
        string upiId,
        string? purpose = null,
        CancellationToken ct = default)
    {
        var payoutId = $"pout_mock_{Interlocked.Increment(ref _counter)}";
        var utr = $"UTR{DateTimeOffset.UtcNow:yyyyMMddHHmmss}{_counter:D6}";

        _logger.LogInformation("MOCK UPI PAYOUT: ₹{Amount} to {Upi}. PayoutId: {PayoutId}, UTR: {Utr}",
            amount, upiId, payoutId, utr);

        return Task.FromResult(new PayoutResult(
            Success: true,
            ProviderPayoutId: payoutId,
            UtrNumber: utr,
            FailureReason: null));
    }

    public Task<PayoutStatusResult> GetPayoutStatusAsync(string providerPayoutId, CancellationToken ct = default)
    {
        return Task.FromResult(new PayoutStatusResult(
            Status: "processed",
            UtrNumber: $"UTR{DateTimeOffset.UtcNow:yyyyMMddHHmmss}",
            FailureReason: null));
    }
}
