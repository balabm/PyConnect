namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Invoicing;
using PondyConnect.Domain.Enums;

/// <summary>
/// Admin finance dashboard endpoints. Provides GMV, commission revenue,
/// driver payout liabilities and recent settlement logs. All endpoints
/// require the Admin role.
/// </summary>
[ApiController]
[Route("api/admin/finance")]
[Authorize(Roles = "Admin")]
public sealed class AdminFinanceController : ControllerBase
{
    private readonly IApplicationDbContext _context;
    private readonly InvoiceService _invoiceService;

    public AdminFinanceController(IApplicationDbContext context, InvoiceService invoiceService)
    {
        _context = context;
        _invoiceService = invoiceService;
    }

    /// <summary>
    /// Returns the high-level finance summary: GMV, commission revenue,
    /// driver payouts due and total transaction count.
    /// </summary>
    [HttpGet("summary")]
    [HttpGet]
    [ProducesResponseType(typeof(AdminFinanceSummaryResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<AdminFinanceSummaryResponse>> GetSummary(CancellationToken cancellationToken)
    {
        var capturedPayments = _context.Payments.AsNoTracking()
            .Where(p => p.Status == PaymentStatus.Captured);

        var gmv = await capturedPayments.SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0m;
        var totalTransactions = await capturedPayments.CountAsync(cancellationToken);

        // Platform takes 0% commission currently.
        const decimal commissionRevenue = 0m;

        // Driver payouts due = sum of pending settlement driver payouts.
        var driverPayoutsDue = await _context.PaymentSettlements.AsNoTracking()
            .Where(s => s.SettlementStatus == SettlementStatus.Pending)
            .SumAsync(s => (decimal?)s.DriverPayout, cancellationToken) ?? 0m;

        return Ok(new AdminFinanceSummaryResponse(
            gmv,
            commissionRevenue,
            driverPayoutsDue,
            totalTransactions));
    }

    /// <summary>
    /// Returns recent Razorpay settlement logs (captured payments ordered by
    /// creation date descending, most recent 50).
    /// </summary>
    [HttpGet("settlements")]
    [ProducesResponseType(typeof(IReadOnlyList<SettlementLogResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SettlementLogResponse>>> GetSettlements(CancellationToken cancellationToken)
    {
        var settlements = await _context.Payments.AsNoTracking()
            .Where(p => p.Status == PaymentStatus.Captured)
            .OrderByDescending(p => p.CreatedAt)
            .Take(50)
            .Select(p => new SettlementLogResponse(
                p.Id,
                p.Amount,
                "INR",
                p.Status.ToString(),
                p.ProviderOrderId,
                p.ProviderPaymentId,
                p.CreatedAt))
            .ToListAsync(cancellationToken);

        return Ok(settlements);
    }

    // ── GST Invoice Management ──

    /// <summary>
    /// Manually triggers GST invoice generation for a specific month.
    /// Useful for testing or re-generating invoices if the cron job failed.
    /// </summary>
    [HttpPost("invoices/generate")]
    [ProducesResponseType(typeof(GenerateInvoicesResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<GenerateInvoicesResponse>> GenerateInvoices(
        [FromQuery] int year,
        [FromQuery] int month,
        CancellationToken cancellationToken)
    {
        if (month < 1 || month > 12)
            return BadRequest(new { Message = "Month must be between 1 and 12." });

        var invoices = await _invoiceService.GenerateMonthlyInvoicesAsync(year, month, cancellationToken);
        return Ok(new GenerateInvoicesResponse(year, month, invoices.Count, invoices.Select(i => i.InvoiceNumber).ToList()));
    }

    /// <summary>
    /// Lists all tax invoices, optionally filtered by vendor or month.
    /// </summary>
    [HttpGet("invoices")]
    [ProducesResponseType(typeof(IReadOnlyList<TaxInvoiceResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TaxInvoiceResponse>>> ListInvoices(
        [FromQuery] Guid? vendorId = null,
        [FromQuery] string? month = null,
        CancellationToken cancellationToken = default)
    {
        var query = _context.TaxInvoices.AsNoTracking();

        if (vendorId is not null)
            query = query.Where(i => i.VendorId == vendorId.Value);
        if (!string.IsNullOrWhiteSpace(month))
            query = query.Where(i => i.InvoiceMonth == month);

        var invoices = await query
            .OrderByDescending(i => i.GeneratedAt)
            .Select(i => new TaxInvoiceResponse(
                i.Id,
                i.VendorId,
                i.InvoiceNumber,
                i.InvoiceMonth,
                i.BaseCommission,
                i.CgstAmount,
                i.SgstAmount,
                i.TotalAmount,
                i.TransactionCount,
                i.PdfUrl,
                i.IsEmailed,
                i.GeneratedAt))
            .ToListAsync(cancellationToken);

        return Ok(invoices);
    }
}

public sealed record AdminFinanceSummaryResponse(
    decimal Gmv,
    decimal CommissionRevenue,
    decimal DriverPayoutsDue,
    int TotalTransactions);

public sealed record SettlementLogResponse(
    Guid PaymentId,
    decimal Amount,
    string Currency,
    string Status,
    string? ProviderOrderId,
    string? ProviderPaymentId,
    DateTimeOffset CapturedAt);

public sealed record GenerateInvoicesResponse(int Year, int Month, int InvoiceCount, IReadOnlyList<string> InvoiceNumbers);
public sealed record TaxInvoiceResponse(
    Guid Id,
    Guid VendorId,
    string InvoiceNumber,
    string InvoiceMonth,
    decimal BaseCommission,
    decimal CgstAmount,
    decimal SgstAmount,
    decimal TotalAmount,
    int TransactionCount,
    string? PdfUrl,
    bool IsEmailed,
    DateTimeOffset GeneratedAt);
