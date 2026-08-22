namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// Tracks a single payout request to a vendor or driver via RazorpayX.
/// Links to the double-entry ledger and records bank-level details
/// including the UTR number returned by the bank.
/// </summary>
public sealed class PayoutRequest : BaseEntity
{
    public PayoutRecipientType RecipientType { get; private set; }

    public Guid RecipientId { get; private set; }

    public decimal Amount { get; private set; }

    public decimal TdsDeducted { get; private set; }

    public decimal NetAmount { get; private set; }

    public PayoutStatus Status { get; private set; } = PayoutStatus.Pending;

    /// <summary>
    /// Bank account number or UPI ID the payout was sent to.
    /// </summary>
    public string? DestinationAccount { get; private set; }

    public string? DestinationIfsc { get; private set; }

    public string? DestinationUpi { get; private set; }

    /// <summary>
    /// RazorpayX payout ID returned by the API.
    /// </summary>
    public string? ProviderPayoutId { get; private set; }

    /// <summary>
    /// Bank UTR (Unique Transaction Reference) number received on success.
    /// </summary>
    public string? UtrNumber { get; private set; }

    /// <summary>
    /// Failure reason if the payout was reversed or bounced.
    /// </summary>
    public string? FailureReason { get; private set; }

    /// <summary>
    /// The ledger transaction ID grouping the payout's double-entry rows.
    /// </summary>
    public Guid? LedgerTransactionId { get; private set; }

    /// <summary>
    /// Settlement IDs included in this payout (comma-separated for audit).
    /// </summary>
    public string? SettlementIds { get; private set; }

    public DateTimeOffset? ProcessedAt { get; private set; }

    public DateTimeOffset? FailedAt { get; private set; }

    private PayoutRequest()
    {
    }

    public static PayoutRequest CreateForVendor(
        Guid vendorId,
        decimal amount,
        decimal tdsDeducted,
        string? bankAccountNumber,
        string? ifsc,
        string? settlementIds = null)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(bankAccountNumber);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));

        return new PayoutRequest
        {
            RecipientType = PayoutRecipientType.Vendor,
            RecipientId = vendorId,
            Amount = amount,
            TdsDeducted = tdsDeducted,
            NetAmount = amount - tdsDeducted,
            Status = PayoutStatus.Pending,
            DestinationAccount = bankAccountNumber,
            DestinationIfsc = ifsc,
            SettlementIds = settlementIds
        };
    }

    public static PayoutRequest CreateForDriver(
        Guid driverId,
        decimal amount,
        string? upiId,
        string? settlementIds = null)
    {
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));

        return new PayoutRequest
        {
            RecipientType = PayoutRecipientType.Driver,
            RecipientId = driverId,
            Amount = amount,
            TdsDeducted = 0m,
            NetAmount = amount,
            Status = PayoutStatus.Pending,
            DestinationUpi = upiId,
            SettlementIds = settlementIds
        };
    }

    public void MarkProcessing(string providerPayoutId)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(providerPayoutId);
        if (Status != PayoutStatus.Pending)
            throw new InvalidOperationException("Payout is not in pending state.");
        Status = PayoutStatus.Processing;
        ProviderPayoutId = providerPayoutId;
        MarkUpdated();
    }

    public void MarkCompleted(string utrNumber)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(utrNumber);
        if (Status != PayoutStatus.Processing)
            throw new InvalidOperationException("Payout is not in processing state.");
        Status = PayoutStatus.Completed;
        UtrNumber = utrNumber;
        ProcessedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void MarkFailed(string reason)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(reason);
        if (Status is PayoutStatus.Completed or PayoutStatus.Cancelled)
            throw new InvalidOperationException("Payout is already completed or cancelled.");
        Status = PayoutStatus.Failed;
        FailureReason = reason;
        FailedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    public void Cancel()
    {
        if (Status != PayoutStatus.Pending)
            throw new InvalidOperationException("Only pending payouts can be cancelled.");
        Status = PayoutStatus.Cancelled;
        MarkUpdated();
    }

    public void RecordLedgerTransaction(Guid ledgerTransactionId)
    {
        LedgerTransactionId = ledgerTransactionId;
        MarkUpdated();
    }
}
