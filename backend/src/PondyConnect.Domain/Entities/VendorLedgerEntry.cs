namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// Tracks platform commission collected from a vendor for each
/// transaction. Used by the monthly GST invoicing worker to generate
/// tax invoices for vendors to claim Input Tax Credit (ITC).
/// </summary>
public sealed class VendorLedgerEntry : BaseEntity
{
    public Guid VendorId { get; private set; }

    /// <summary>
    /// The order/booking/ride ID that generated this commission.
    /// </summary>
    public Guid ReferenceId { get; private set; }

    /// <summary>
    /// Type of transaction: "FoodOrder", "Ride", "Rental", "Homestay", etc.
    /// </summary>
    public string ReferenceType { get; private set; } = string.Empty;

    /// <summary>
    /// Gross transaction amount.
    /// </summary>
    public decimal GrossAmount { get; private set; }

    /// <summary>
    /// Platform commission amount collected.
    /// </summary>
    public decimal CommissionAmount { get; private set; }

    /// <summary>
    /// GST component (18% of commission = 9% CGST + 9% SGST).
    /// </summary>
    public decimal GstAmount { get; private set; }

    /// <summary>
    /// Total commission including GST.
    /// </summary>
    public decimal TotalCommission { get; private set; }

    public DateTimeOffset TransactionDate { get; private set; }

    /// <summary>
    /// The invoice ID if this entry has been included in a monthly invoice.
    /// Null if not yet invoiced.
    /// </summary>
    public Guid? InvoiceId { get; private set; }

    private VendorLedgerEntry()
    {
    }

    public static VendorLedgerEntry Create(
        Guid vendorId,
        Guid referenceId,
        string referenceType,
        decimal grossAmount,
        decimal commissionAmount,
        DateTimeOffset? transactionDate = null)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        if (referenceId == Guid.Empty)
            throw new ArgumentException("Reference ID is required.", nameof(referenceId));
        ArgumentException.ThrowIfNullOrWhiteSpace(referenceType);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(commissionAmount, nameof(commissionAmount));

        var gst = Math.Round(commissionAmount * 0.18m, 2, MidpointRounding.AwayFromZero);
        var total = commissionAmount + gst;

        return new VendorLedgerEntry
        {
            VendorId = vendorId,
            ReferenceId = referenceId,
            ReferenceType = referenceType,
            GrossAmount = grossAmount,
            CommissionAmount = commissionAmount,
            GstAmount = gst,
            TotalCommission = total,
            TransactionDate = transactionDate ?? DateTimeOffset.UtcNow
        };
    }

    /// <summary>
    /// Mark this entry as invoiced in a monthly GST invoice.
    /// </summary>
    public void MarkInvoiced(Guid invoiceId)
    {
        if (InvoiceId is not null)
            throw new InvalidOperationException("Entry is already invoiced.");
        InvoiceId = invoiceId;
        MarkUpdated();
    }
}
