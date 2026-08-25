namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Invoicing;
using PondyConnect.Application.Features.Settlement;
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
    private readonly SettlementService _settlementService;
    private readonly ChargebackService _chargebackService;

    public AdminFinanceController(
        IApplicationDbContext context,
        InvoiceService invoiceService,
        SettlementService settlementService,
        ChargebackService chargebackService)
    {
        _context = context;
        _invoiceService = invoiceService;
        _settlementService = settlementService;
        _chargebackService = chargebackService;
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
        // GMV: sum of all captured payments. Use nullable cast so empty
        // tables return 0 instead of throwing.
        var capturedPayments = _context.Payments.AsNoTracking()
            .Where(p => p.Status == PaymentStatus.Captured);

        var gmv = await capturedPayments.SumAsync(p => (decimal?)p.Amount, cancellationToken) ?? 0m;
        var totalTransactions = await capturedPayments.CountAsync(cancellationToken);

        // Completed orders: count food orders delivered + rides completed.
        // These are the fulfilled orders that actually generated revenue.
        var completedFoodOrders = await _context.FoodOrders.AsNoTracking()
            .Where(o => o.Status == FoodOrderStatus.Delivered)
            .CountAsync(cancellationToken);

        var completedRides = await _context.RideRequests.AsNoTracking()
            .Where(r => r.Status == RideStatus.Completed)
            .CountAsync(cancellationToken);

        var completedOrders = completedFoodOrders + completedRides;

        // Platform takes 0% commission currently.
        const decimal commissionRevenue = 0m;

        // Driver payouts due = sum of pending settlement driver payouts.
        // Empty table → 0m via nullable coalesce.
        var driverPayoutsDue = await _context.PaymentSettlements.AsNoTracking()
            .Where(s => s.SettlementStatus == SettlementStatus.Pending)
            .SumAsync(s => (decimal?)s.DriverPayout, cancellationToken) ?? 0m;

        return Ok(new AdminFinanceSummaryResponse(
            gmv,
            commissionRevenue,
            driverPayoutsDue,
            totalTransactions,
            completedOrders));
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

    // ── Settlement & Payout Management ──

    /// <summary>
    /// Manually triggers vendor and driver payout processing.
    /// Useful for testing or when the daily cron job failed.
    /// </summary>
    [HttpPost("settlements/process")]
    [ProducesResponseType(typeof(ProcessSettlementsResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ProcessSettlementsResponse>> ProcessSettlements(
        [FromQuery] string type = "all",
        CancellationToken cancellationToken = default)
    {
        var vendorPayouts = 0;
        var driverPayouts = 0;

        if (type is "all" or "vendor")
            vendorPayouts = await _settlementService.ProcessVendorPayoutsAsync(cancellationToken);
        if (type is "all" or "driver")
            driverPayouts = await _settlementService.ProcessDriverPayoutsAsync(cancellationToken);

        return Ok(new ProcessSettlementsResponse(vendorPayouts, driverPayouts));
    }

    /// <summary>
    /// Lists all payout requests with optional status filter.
    /// </summary>
    [HttpGet("payouts")]
    [ProducesResponseType(typeof(IReadOnlyList<PayoutResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<PayoutResponse>>> ListPayouts(
        [FromQuery] string? status = null,
        CancellationToken cancellationToken = default)
    {
        var query = _context.PayoutRequests.AsNoTracking();

        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<PayoutStatus>(status, true, out var statusEnum))
            query = query.Where(p => p.Status == statusEnum);

        var payouts = await query
            .OrderByDescending(p => p.CreatedAt)
            .Select(p => new PayoutResponse(
                p.Id,
                p.RecipientType.ToString(),
                p.RecipientId,
                p.Amount,
                p.TdsDeducted,
                p.NetAmount,
                p.Status.ToString(),
                p.ProviderPayoutId,
                p.UtrNumber,
                p.FailureReason,
                p.ProcessedAt,
                p.CreatedAt))
            .ToListAsync(cancellationToken);

        return Ok(payouts);
    }

    // ── Chargeback Management ──

    /// <summary>
    /// Lists all chargeback disputes for the admin dashboard.
    /// </summary>
    [HttpGet("chargebacks")]
    [ProducesResponseType(typeof(IReadOnlyList<ChargebackResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<ChargebackResponse>>> ListChargebacks(
        [FromQuery] string? status = null,
        CancellationToken cancellationToken = default)
    {
        ChargebackStatus? statusFilter = null;
        if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<ChargebackStatus>(status, true, out var statusEnum))
            statusFilter = statusEnum;

        var disputes = await _chargebackService.ListDisputesAsync(statusFilter, cancellationToken);

        return Ok(disputes.Select(d => new ChargebackResponse(
            d.Id,
            d.PaymentId,
            d.UserId,
            d.OrderId,
            d.OrderType,
            d.ChargebackAmount,
            d.Status.ToString(),
            d.AccountFrozen,
            d.EvidenceSummary,
            d.ResolutionNote,
            d.CreatedAt,
            d.ResolvedAt)).ToList());
    }

    /// <summary>
    /// Resolves a chargeback dispute (admin action).
    /// </summary>
    [HttpPost("chargebacks/{id:guid}/resolve")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveChargeback(
        Guid id,
        [FromBody] ResolveChargebackRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
            await _chargebackService.ResolveDisputeAsync(id, request.Won, request.Note ?? "", cancellationToken);
            return Ok(new { Message = "Chargeback resolved." });
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
    }
}

public sealed record AdminFinanceSummaryResponse(
    decimal Gmv,
    decimal CommissionRevenue,
    decimal DriverPayoutsDue,
    int TotalTransactions,
    int CompletedOrders);

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

public sealed record ProcessSettlementsResponse(int VendorPayouts, int DriverPayouts);
public sealed record PayoutResponse(
    Guid Id,
    string RecipientType,
    Guid RecipientId,
    decimal Amount,
    decimal TdsDeducted,
    decimal NetAmount,
    string Status,
    string? ProviderPayoutId,
    string? UtrNumber,
    string? FailureReason,
    DateTimeOffset? ProcessedAt,
    DateTimeOffset CreatedAt);
public sealed record ChargebackResponse(
    Guid Id,
    Guid PaymentId,
    Guid UserId,
    Guid? OrderId,
    string? OrderType,
    decimal ChargebackAmount,
    string Status,
    bool AccountFrozen,
    string? EvidenceSummary,
    string? ResolutionNote,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt);
public sealed record ResolveChargebackRequest(bool Won, string? Note);
