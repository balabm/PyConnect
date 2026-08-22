namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;

/// <summary>
/// A single entry in the double-entry ledger. Every financial
/// transaction produces two or more <see cref="LedgerEntry"/> rows
/// (one debit, one credit) that must sum to zero for that transaction.
///
/// Example — ₹1,000 food order:
///   Debit  RazorpayReceivable  ₹1,000
///   Credit PartnerPayable         ₹800
///   Credit CaptainPayable         ₹100
///   Credit PlatformRevenue         ₹82
///   Credit GstOutputPayable        ₹18
/// </summary>
public sealed class LedgerEntry : BaseEntity
{
    /// <summary>
    /// Groups all entries for a single transaction (e.g., order payment).
    /// All entries with the same TransactionId must sum to zero.
    /// </summary>
    public Guid TransactionId { get; private set; }

    public AccountType Account { get; private set; }

    /// <summary>
    /// True = debit (asset increase / liability decrease).
    /// False = credit (asset decrease / liability increase).
    /// </summary>
    public bool IsDebit { get; private set; }

    public decimal Amount { get; private set; }

    /// <summary>
    /// "Order", "Ride", "Refund", "Payout", "Rental", "ServiceBooking".
    /// </summary>
    public string ReferenceType { get; private set; } = string.Empty;

    public Guid ReferenceId { get; private set; }

    /// <summary>
    /// Optional: the vendor or driver this entry relates to.
    /// </summary>
    public Guid? VendorId { get; private set; }

    public Guid? DriverId { get; private set; }

    /// <summary>
    /// Human-readable description for audit logs.
    /// </summary>
    public string Description { get; private set; } = string.Empty;

    private LedgerEntry()
    {
    }

    public static LedgerEntry Create(
        Guid transactionId,
        AccountType account,
        bool isDebit,
        decimal amount,
        string referenceType,
        Guid referenceId,
        string description,
        Guid? vendorId = null,
        Guid? driverId = null)
    {
        if (transactionId == Guid.Empty)
            throw new ArgumentException("Transaction ID is required.", nameof(transactionId));
        ArgumentException.ThrowIfNullOrWhiteSpace(referenceType);
        ArgumentException.ThrowIfNullOrWhiteSpace(description);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(amount, nameof(amount));

        return new LedgerEntry
        {
            TransactionId = transactionId,
            Account = account,
            IsDebit = isDebit,
            Amount = amount,
            ReferenceType = referenceType,
            ReferenceId = referenceId,
            Description = description,
            VendorId = vendorId,
            DriverId = driverId
        };
    }
}
