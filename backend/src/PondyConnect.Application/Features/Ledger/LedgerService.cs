namespace PondyConnect.Application.Features.Ledger;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Records double-entry ledger entries for every financial transaction
/// in the system. Every rupee that flows through PY Connect must balance:
/// the sum of all debits must equal the sum of all credits for each
/// transaction.
///
/// Example — ₹1,000 food order (₹800 vendor, ₹100 driver, ₹82 platform, ₹18 GST):
///   Debit  RazorpayReceivable  ₹1,000
///   Credit PartnerPayable         ₹800
///   Credit CaptainPayable         ₹100
///   Credit PlatformRevenue         ₹82
///   Credit GstOutputPayable        ₹18
/// </summary>
public sealed class LedgerService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<LedgerService> _logger;
    private readonly TaxOptions _tax;

    public decimal TdsRate => _tax.TdsRate;

    public LedgerService(IApplicationDbContext context, ILogger<LedgerService> logger, IOptions<TaxOptions> taxOptions)
    {
        _context = context;
        _logger = logger;
        _tax = taxOptions.Value;
    }

    /// <summary>
    /// Records the double-entry ledger for a food order payment.
    /// Called after payment capture and settlement calculation.
    /// </summary>
    public async Task<Guid> RecordFoodOrderPaymentAsync(
        Guid paymentId,
        Guid foodOrderId,
        Guid vendorId,
        decimal grossAmount,
        decimal vendorPayout,
        decimal driverPayout,
        decimal platformFee,
        decimal gstAmount,
        Guid? driverId = null,
        CancellationToken ct = default)
    {
        var transactionId = Guid.NewGuid();
        var entries = new List<LedgerEntry>();

        // Debit: Razorpay received the money
        entries.Add(LedgerEntry.Create(
            transactionId, AccountType.RazorpayReceivable, isDebit: true,
            grossAmount, "Order", foodOrderId,
            $"Food order {foodOrderId} payment received",
            vendorId, driverId));

        // Credit: vendor payable
        if (vendorPayout > 0)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.PartnerPayable, isDebit: false,
                vendorPayout, "Order", foodOrderId,
                $"Vendor payout for order {foodOrderId}",
                vendorId, driverId));

        // Credit: driver payable (delivery fee)
        if (driverPayout > 0 && driverId is not null)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.CaptainPayable, isDebit: false,
                driverPayout, "Order", foodOrderId,
                $"Driver payout for order {foodOrderId}",
                vendorId, driverId));

        // Credit: platform revenue (commission)
        if (platformFee > 0)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.PlatformRevenue, isDebit: false,
                platformFee, "Order", foodOrderId,
                $"Platform commission for order {foodOrderId}",
                vendorId, driverId));

        // Credit: GST output on commission (18%)
        if (gstAmount > 0)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.GstOutputPayable, isDebit: false,
                gstAmount, "Order", foodOrderId,
                $"GST output (18%) on commission for order {foodOrderId}",
                vendorId, driverId));

        _context.LedgerEntries.AddRange(entries);
        await _context.SaveChangesAsync(ct);

        _logger.LedgerRecorded("FoodOrder", foodOrderId, transactionId, grossAmount);
        return transactionId;
    }

    /// <summary>
    /// Records the double-entry ledger for a ride payment.
    /// </summary>
    public async Task<Guid> RecordRidePaymentAsync(
        Guid paymentId,
        Guid rideRequestId,
        Guid driverId,
        decimal grossAmount,
        decimal driverPayout,
        decimal platformFee,
        CancellationToken ct = default)
    {
        var transactionId = Guid.NewGuid();
        var entries = new List<LedgerEntry>
        {
            LedgerEntry.Create(
                transactionId, AccountType.RazorpayReceivable, isDebit: true,
                grossAmount, "Ride", rideRequestId,
                $"Ride {rideRequestId} payment received",
                driverId: driverId)
        };

        if (driverPayout > 0)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.CaptainPayable, isDebit: false,
                driverPayout, "Ride", rideRequestId,
                $"Driver payout for ride {rideRequestId}",
                driverId: driverId));

        if (platformFee > 0)
        {
            var gstOnFee = Math.Round(platformFee * _tax.PlatformGstRate, 2, MidpointRounding.AwayFromZero);
            var netFee = platformFee - gstOnFee;

            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.PlatformRevenue, isDebit: false,
                netFee, "Ride", rideRequestId,
                $"Platform commission for ride {rideRequestId}",
                driverId: driverId));

            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.GstOutputPayable, isDebit: false,
                gstOnFee, "Ride", rideRequestId,
                $"GST output (18%) on commission for ride {rideRequestId}",
                driverId: driverId));
        }

        _context.LedgerEntries.AddRange(entries);
        await _context.SaveChangesAsync(ct);

        _logger.LedgerRecorded("Ride", rideRequestId, transactionId, grossAmount);
        return transactionId;
    }

    /// <summary>
    /// Records the double-entry ledger for a refund.
    /// Reverses the original Razorpay receivable and credits the refund.
    /// </summary>
    public async Task<Guid> RecordRefundAsync(
        Guid originalPaymentId,
        Guid referenceId,
        string referenceType,
        decimal refundAmount,
        Guid? vendorId = null,
        Guid? driverId = null,
        CancellationToken ct = default)
    {
        var transactionId = Guid.NewGuid();

        var entries = new List<LedgerEntry>
        {
            // Credit: reverse the Razorpay receivable (money going back)
            LedgerEntry.Create(
                transactionId, AccountType.RazorpayReceivable, isDebit: false,
                refundAmount, "Refund", referenceId,
                $"Refund for {referenceType} {referenceId}",
                vendorId, driverId),

            // Debit: refund expense
            LedgerEntry.Create(
                transactionId, AccountType.RefundExpense, isDebit: true,
                refundAmount, "Refund", referenceId,
                $"Refund expense for {referenceType} {referenceId}",
                vendorId, driverId)
        };

        _context.LedgerEntries.AddRange(entries);
        await _context.SaveChangesAsync(ct);

        _logger.LedgerRecorded("Refund", referenceId, transactionId, refundAmount);
        return transactionId;
    }

    /// <summary>
    /// Records the double-entry ledger for a vendor payout.
    /// Debits PartnerPayable and credits EscrowHold (cash leaving).
    /// </summary>
    public async Task<Guid> RecordVendorPayoutAsync(
        Guid payoutRequestId,
        Guid vendorId,
        decimal payoutAmount,
        decimal tdsDeducted,
        CancellationToken ct = default)
    {
        var transactionId = Guid.NewGuid();
        var netPayout = payoutAmount - tdsDeducted;

        var entries = new List<LedgerEntry>
        {
            // Debit: reduce partner payable
            LedgerEntry.Create(
                transactionId, AccountType.PartnerPayable, isDebit: true,
                payoutAmount, "Payout", payoutRequestId,
                $"Payout to vendor {vendorId}",
                vendorId: vendorId),

            // Credit: cash leaving escrow
            LedgerEntry.Create(
                transactionId, AccountType.EscrowHold, isDebit: false,
                netPayout, "Payout", payoutRequestId,
                $"Net payout transferred to vendor {vendorId}",
                vendorId: vendorId)
        };

        if (tdsDeducted > 0)
            entries.Add(LedgerEntry.Create(
                transactionId, AccountType.TdsPayable, isDebit: false,
                tdsDeducted, "Payout", payoutRequestId,
                $"TDS (194O) deducted from vendor {vendorId} payout",
                vendorId: vendorId));

        _context.LedgerEntries.AddRange(entries);
        await _context.SaveChangesAsync(ct);

        _logger.LedgerRecorded("Payout", payoutRequestId, transactionId, payoutAmount);
        return transactionId;
    }

    /// <summary>
    /// Records the double-entry ledger for a driver payout.
    /// </summary>
    public async Task<Guid> RecordDriverPayoutAsync(
        Guid payoutRequestId,
        Guid driverId,
        decimal payoutAmount,
        CancellationToken ct = default)
    {
        var transactionId = Guid.NewGuid();

        var entries = new List<LedgerEntry>
        {
            LedgerEntry.Create(
                transactionId, AccountType.CaptainPayable, isDebit: true,
                payoutAmount, "Payout", payoutRequestId,
                $"Payout to driver {driverId}",
                driverId: driverId),

            LedgerEntry.Create(
                transactionId, AccountType.EscrowHold, isDebit: false,
                payoutAmount, "Payout", payoutRequestId,
                $"Payout transferred to driver {driverId}",
                driverId: driverId)
        };

        _context.LedgerEntries.AddRange(entries);
        await _context.SaveChangesAsync(ct);

        _logger.LedgerRecorded("Payout", payoutRequestId, transactionId, payoutAmount);
        return transactionId;
    }

    /// <summary>
    /// Verifies that a transaction's entries sum to zero (balanced).
    /// Returns true if balanced, false otherwise.
    /// </summary>
    public async Task<bool> IsTransactionBalancedAsync(Guid transactionId, CancellationToken ct = default)
    {
        var entries = await _context.LedgerEntries
            .Where(e => e.TransactionId == transactionId)
            .ToListAsync(ct);

        var sum = entries.Sum(e => e.IsDebit ? e.Amount : -e.Amount);
        return Math.Abs(sum) < 0.01m;
    }

    /// <summary>
    /// Gets the current payable balance for a vendor (credits - debits).
    /// Positive = vendor is owed money, zero = fully paid out.
    /// </summary>
    public async Task<decimal> GetVendorPayableBalanceAsync(Guid vendorId, CancellationToken ct = default)
    {
        var entries = await _context.LedgerEntries
            .Where(e => e.VendorId == vendorId && e.Account == AccountType.PartnerPayable)
            .ToListAsync(ct);

        return entries.Sum(e => e.IsDebit ? -e.Amount : e.Amount);
    }

    /// <summary>
    /// Gets the current payable balance for a driver (credits - debits).
    /// </summary>
    public async Task<decimal> GetDriverPayableBalanceAsync(Guid driverId, CancellationToken ct = default)
    {
        var entries = await _context.LedgerEntries
            .Where(e => e.DriverId == driverId && e.Account == AccountType.CaptainPayable)
            .ToListAsync(ct);

        return entries.Sum(e => e.IsDebit ? -e.Amount : e.Amount);
    }
}

internal static partial class LedgerLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Ledger recorded: {Type} {ReferenceId} → Transaction {TransactionId}, Amount: ₹{Amount}")]
    public static partial void LedgerRecorded(this ILogger logger, string type, Guid referenceId, Guid transactionId, decimal amount);
}
