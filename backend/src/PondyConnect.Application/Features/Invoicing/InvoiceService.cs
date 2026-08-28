namespace PondyConnect.Application.Features.Invoicing;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using System.Globalization;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

/// <summary>
/// Generates monthly GST tax invoices for vendors. Scans the
/// VendorLedgerEntry table for the previous month's commissions,
/// creates a TaxInvoice record, generates a compliant PDF with
/// CGST (9%) and SGST (9%) split, and stores it in S3.
/// </summary>
public sealed class InvoiceService
{
    private readonly IApplicationDbContext _context;
    private readonly IStorageService _storage;
    private readonly ILogger<InvoiceService> _logger;
    private readonly InvoiceOptions _options;

    public string PlatformGstin => _options.PlatformGstin;
    public string PlatformName => _options.PlatformName;
    public string PlatformAddress => _options.PlatformAddress;

    public InvoiceService(
        IApplicationDbContext context,
        IStorageService storage,
        ILogger<InvoiceService> logger,
        IOptions<InvoiceOptions> options)
    {
        _context = context;
        _storage = storage;
        _logger = logger;
        _options = options.Value;
    }

    /// <summary>
    /// Generates monthly GST invoices for all vendors with commission
    /// entries in the specified month. Returns the list of generated invoices.
    /// </summary>
    public async Task<List<TaxInvoice>> GenerateMonthlyInvoicesAsync(
        int year,
        int month,
        CancellationToken ct = default)
    {
        var startDate = new DateTimeOffset(year, month, 1, 0, 0, 0, TimeSpan.Zero);
        var endDate = startDate.AddMonths(1);

        // Find all vendors with uninvoiced ledger entries in the target month
        var vendorIds = await _context.VendorLedgerEntries
            .Where(e => e.TransactionDate >= startDate
                && e.TransactionDate < endDate
                && e.InvoiceId == null)
            .Select(e => e.VendorId)
            .Distinct()
            .ToListAsync(ct);

        var invoices = new List<TaxInvoice>();

        foreach (var vendorId in vendorIds)
        {
            try
            {
                var invoice = await GenerateInvoiceForVendorAsync(vendorId, year, month, startDate, endDate, ct);
                if (invoice is not null)
                    invoices.Add(invoice);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to generate invoice for vendor {VendorId} for {Year}-{Month}", vendorId, year, month);
            }
        }

        _logger.MonthlyInvoicesGenerated(year, month, invoices.Count);
        return invoices;
    }

    private async Task<TaxInvoice?> GenerateInvoiceForVendorAsync(
        Guid vendorId,
        int year,
        int month,
        DateTimeOffset startDate,
        DateTimeOffset endDate,
        CancellationToken ct)
    {
        var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == vendorId, ct);
        if (vendor is null)
            return null;

        // Get uninvoiced entries for this vendor in the target month
        var entries = await _context.VendorLedgerEntries
            .Where(e => e.VendorId == vendorId
                && e.TransactionDate >= startDate
                && e.TransactionDate < endDate
                && e.InvoiceId == null)
            .ToListAsync(ct);

        if (entries.Count == 0)
            return null;

        var baseCommission = entries.Sum(e => e.CommissionAmount);
        var invoiceNumber = $"PYC-GST-{year}-{month:D2}-{vendorId.ToString()[..8].ToUpperInvariant()}";
        var invoiceMonth = $"{year}-{month:D2}";

        // Create the invoice record
        var invoice = TaxInvoice.Create(vendorId, invoiceNumber, invoiceMonth, baseCommission, entries.Count);
        _context.TaxInvoices.Add(invoice);
        await _context.SaveChangesAsync(ct);

        // Mark ledger entries as invoiced
        foreach (var entry in entries)
            entry.MarkInvoiced(invoice.Id);

        // Generate the PDF
        var pdfBytes = GeneratePdf(invoice, vendor, entries, _options);
        var fileName = $"invoices/{invoiceMonth}/{invoiceNumber}.pdf";

        await using var stream = new MemoryStream(pdfBytes);
        var pdfUrl = await _storage.UploadFileAsync(stream, fileName, "application/pdf", isPrivate: true, cancellationToken: ct);
        invoice.RecordPdfUrl(pdfUrl);

        await _context.SaveChangesAsync(ct);

        _logger.InvoiceGenerated(vendorId, invoiceNumber, invoice.TotalAmount);
        return invoice;
    }

    private static byte[] GeneratePdf(TaxInvoice invoice, Vendor vendor, List<VendorLedgerEntry> entries, InvoiceOptions options)
    {
        QuestPDF.Settings.License = LicenseType.Community;

        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(40);
                page.DefaultTextStyle(x => x.FontSize(10).FontFamily("Helvetica"));

                page.Header().Column(col =>
                {
                    col.Item().Text(options.PlatformName).SemiBold().FontSize(16);
                    col.Item().Text(options.PlatformAddress).FontSize(9);
                    col.Item().Text($"GSTIN: {options.PlatformGstin}").FontSize(9);
                    col.Item().PaddingVertical(5).LineHorizontal(1).LineColor(Colors.Grey.Lighten2);
                    col.Item().Text("TAX INVOICE").Bold().FontSize(14).FontColor(Colors.Blue.Darken2);
                    col.Item().Text($"Invoice No: {invoice.InvoiceNumber}").FontSize(10);
                    col.Item().Text($"Period: {invoice.InvoiceMonth}").FontSize(10);
                    col.Item().Text($"Date: {invoice.GeneratedAt:dd MMM yyyy}").FontSize(10);
                });

                page.Content().PaddingVertical(10).Column(col =>
                {
                    // Bill To section
                    col.Item().PaddingBottom(10).Column(billCol =>
                    {
                        billCol.Item().Text("Bill To").SemiBold().FontSize(11);
                        billCol.Item().Text(vendor.Name).FontSize(10);
                        if (!string.IsNullOrWhiteSpace(vendor.GstNumber))
                            billCol.Item().Text($"GSTIN: {vendor.GstNumber}").FontSize(9);
                        if (!string.IsNullOrWhiteSpace(vendor.ContactPhone))
                            billCol.Item().Text($"Phone: {vendor.ContactPhone}").FontSize(9);
                    });

                    // Transaction summary table
                    col.Item().Table(table =>
                    {
                        table.ColumnsDefinition(c =>
                        {
                            c.RelativeColumn(2); // Date
                            c.RelativeColumn(3); // Reference
                            c.RelativeColumn(2); // Gross
                            c.RelativeColumn(2); // Commission
                        });

                        table.Header(header =>
                        {
                            header.Cell().Element(CellStyle).Text("Date").SemiBold();
                            header.Cell().Element(CellStyle).Text("Reference").SemiBold();
                            header.Cell().Element(CellStyle).AlignRight().Text("Gross (INR)").SemiBold();
                            header.Cell().Element(CellStyle).AlignRight().Text("Commission (INR)").SemiBold();

                            static IContainer CellStyle(IContainer c) => c
                                .BorderBottom(1)
                                .BorderColor(Colors.Grey.Lighten2)
                                .PaddingVertical(4);
                        });

                        foreach (var entry in entries)
                        {
                            table.Cell().Element(CellStyle).Text(entry.TransactionDate.ToString("dd MMM", CultureInfo.InvariantCulture));
                            table.Cell().Element(CellStyle).Text($"{entry.ReferenceType} #{entry.ReferenceId.ToString()[..8]}");
                            table.Cell().Element(CellStyle).AlignRight().Text(entry.GrossAmount.ToString("N2", CultureInfo.InvariantCulture));
                            table.Cell().Element(CellStyle).AlignRight().Text(entry.CommissionAmount.ToString("N2", CultureInfo.InvariantCulture));

                            static IContainer CellStyle(IContainer c) => c
                                .BorderBottom(0.5f)
                                .BorderColor(Colors.Grey.Lighten3)
                                .PaddingVertical(3);
                        }
                    });

                    // Tax summary
                    col.Item().PaddingTop(15).AlignRight().Column(taxCol =>
                    {
                        taxCol.Item().Text($"Base Commission: INR {invoice.BaseCommission:N2}").FontSize(10);
                        taxCol.Item().Text($"CGST @ 9%: INR {invoice.CgstAmount:N2}").FontSize(10);
                        taxCol.Item().Text($"SGST @ 9%: INR {invoice.SgstAmount:N2}").FontSize(10);
                        taxCol.Item().PaddingTop(4).Text($"Total Payable: INR {invoice.TotalAmount:N2}").SemiBold().FontSize(12).FontColor(Colors.Blue.Darken2);
                    });

                    col.Item().PaddingTop(20).Text($"Total Transactions: {invoice.TransactionCount}").FontSize(9).FontColor(Colors.Grey.Darken1);
                });

                page.Footer().AlignCenter().Text("This is a computer-generated invoice. Please retain for your records.")
                    .FontSize(8).FontColor(Colors.Grey.Medium);
            });
        });

        return document.GeneratePdf();
    }
}

internal static partial class InvoiceLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Monthly invoices generated for {Year}-{Month}: {Count} invoices")]
    public static partial void MonthlyInvoicesGenerated(this ILogger logger, int year, int month, int count);

    [LoggerMessage(Level = LogLevel.Information, Message = "Invoice {InvoiceNumber} generated for vendor {VendorId}: INR {Amount}")]
    public static partial void InvoiceGenerated(this ILogger logger, Guid vendorId, string invoiceNumber, decimal amount);
}
