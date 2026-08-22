namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;

/// <summary>
/// A monthly GST tax invoice generated for a vendor. Contains the
/// total commission, CGST (9%), SGST (9%), and a PDF URL stored in S3.
/// Emailed to the vendor for Input Tax Credit (ITC) claims.
/// </summary>
public sealed class TaxInvoice : BaseEntity
{
    public Guid VendorId { get; private set; }

    /// <summary>
    /// Invoice number (e.g., "PYC-GST-2026-08-VEND001").
    /// </summary>
    public string InvoiceNumber { get; private set; } = string.Empty;

    /// <summary>
    /// The month this invoice covers (e.g., "2026-08").
    /// </summary>
    public string InvoiceMonth { get; private set; } = string.Empty;

    /// <summary>
    /// Total commission before GST.
    /// </summary>
    public decimal BaseCommission { get; private set; }

    /// <summary>
    /// CGST amount (9% of base commission).
    /// </summary>
    public decimal CgstAmount { get; private set; }

    /// <summary>
    /// SGST amount (9% of base commission).
    /// </summary>
    public decimal SgstAmount { get; private set; }

    /// <summary>
    /// Total invoice amount (base + CGST + SGST).
    /// </summary>
    public decimal TotalAmount { get; private set; }

    /// <summary>
    /// Number of transactions included in this invoice.
    /// </summary>
    public int TransactionCount { get; private set; }

    /// <summary>
    /// S3 URL of the generated PDF invoice.
    /// </summary>
    public string? PdfUrl { get; private set; }

    /// <summary>
    /// Whether the invoice has been emailed to the vendor.
    /// </summary>
    public bool IsEmailed { get; private set; }

    public DateTimeOffset GeneratedAt { get; private set; }

    public DateTimeOffset? EmailedAt { get; private set; }

    private TaxInvoice()
    {
    }

    public static TaxInvoice Create(
        Guid vendorId,
        string invoiceNumber,
        string invoiceMonth,
        decimal baseCommission,
        int transactionCount)
    {
        if (vendorId == Guid.Empty)
            throw new ArgumentException("Vendor ID is required.", nameof(vendorId));
        ArgumentException.ThrowIfNullOrWhiteSpace(invoiceNumber);
        ArgumentException.ThrowIfNullOrWhiteSpace(invoiceMonth);

        var cgst = Math.Round(baseCommission * 0.09m, 2, MidpointRounding.AwayFromZero);
        var sgst = Math.Round(baseCommission * 0.09m, 2, MidpointRounding.AwayFromZero);
        var total = baseCommission + cgst + sgst;

        return new TaxInvoice
        {
            VendorId = vendorId,
            InvoiceNumber = invoiceNumber,
            InvoiceMonth = invoiceMonth,
            BaseCommission = baseCommission,
            CgstAmount = cgst,
            SgstAmount = sgst,
            TotalAmount = total,
            TransactionCount = transactionCount,
            GeneratedAt = DateTimeOffset.UtcNow
        };
    }

    public void RecordPdfUrl(string url)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(url);
        PdfUrl = url;
        MarkUpdated();
    }

    public void MarkEmailed()
    {
        IsEmailed = true;
        EmailedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }
}
