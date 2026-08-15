namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
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

    public AdminFinanceController(IApplicationDbContext context)
    {
        _context = context;
    }

    /// <summary>
    /// Returns the high-level finance summary: GMV, commission revenue,
    /// driver payouts due and total transaction count.
    /// </summary>
    [HttpGet("summary")]
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
                p.Status.ToString(),
                p.ProviderOrderId,
                p.ProviderPaymentId,
                p.CreatedAt))
            .ToListAsync(cancellationToken);

        return Ok(settlements);
    }
}

public sealed record AdminFinanceSummaryResponse(
    decimal Gmv,
    decimal CommissionRevenue,
    decimal DriverPayoutsDue,
    int TotalTransactions);

public sealed record SettlementLogResponse(
    Guid Id,
    decimal Amount,
    string Status,
    string? ProviderOrderId,
    string? ProviderPaymentId,
    DateTimeOffset CreatedAt);
