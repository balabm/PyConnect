namespace PondyConnect.Application.Features.Settlement;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Ledger;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Services;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;

/// <summary>
/// Processes daily payouts to vendors and drivers. Runs at midnight,
/// groups pending settlements by recipient, calculates net payable
/// (minus TDS for vendors), calls the payout service, and records
/// the double-entry ledger.
/// </summary>
public sealed class SettlementService
{
    private readonly IApplicationDbContext _context;
    private readonly IPayoutService _payoutService;
    private readonly LedgerService _ledgerService;
    private readonly INotificationService _notifications;
    private readonly ILogger<SettlementService> _logger;

    /// <summary>
    /// Minimum wallet balance required to trigger a payout.
    /// Prevents micro-payouts that cost more in fees than the amount.
    /// </summary>
    public const decimal MinimumPayoutThreshold = 100m;

    public SettlementService(
        IApplicationDbContext context,
        IPayoutService payoutService,
        LedgerService ledgerService,
        INotificationService notifications,
        ILogger<SettlementService> logger)
    {
        _context = context;
        _payoutService = payoutService;
        _ledgerService = ledgerService;
        _notifications = notifications;
        _logger = logger;
    }

    /// <summary>
    /// Processes payouts for all eligible vendors with pending
    /// settlement balances above the minimum threshold.
    /// </summary>
    public async Task<int> ProcessVendorPayoutsAsync(CancellationToken ct = default)
    {
        // Find vendors with bank-verified accounts and wallet balance above threshold
        var eligibleVendors = await _context.Vendors
            .Where(v => v.IsBankVerified
                && v.WalletBalance >= MinimumPayoutThreshold
                && v.BankAccountNumber != null
                && v.BankIfsc != null)
            .ToListAsync(ct);

        var payoutCount = 0;

        foreach (var vendor in eligibleVendors)
        {
            try
            {
                await ProcessSingleVendorPayoutAsync(vendor, ct);
                payoutCount++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Payout failed for vendor {VendorId}", vendor.Id);
            }
        }

        _logger.DailyPayoutsProcessed("Vendor", payoutCount);
        return payoutCount;
    }

    /// <summary>
    /// Processes payouts for all eligible drivers with pending
    /// settlement balances above the minimum threshold.
    /// </summary>
    public async Task<int> ProcessDriverPayoutsAsync(CancellationToken ct = default)
    {
        // Find drivers with UPI IDs and positive wallet balance above threshold
        var eligibleDrivers = await _context.Drivers
            .Where(d => d.UpiId != null && d.UpiId != "")
            .ToListAsync(ct);

        var payoutCount = 0;

        foreach (var driver in eligibleDrivers)
        {
            try
            {
                // Get the driver's payable balance from the double-entry ledger
                var balance = await _ledgerService.GetDriverPayableBalanceAsync(driver.Id, ct);
                if (balance < MinimumPayoutThreshold)
                    continue;

                await ProcessSingleDriverPayoutAsync(driver, balance, ct);
                payoutCount++;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Payout failed for driver {DriverId}", driver.Id);
            }
        }

        _logger.DailyPayoutsProcessed("Driver", payoutCount);
        return payoutCount;
    }

    private async Task ProcessSingleVendorPayoutAsync(Vendor vendor, CancellationToken ct)
    {
        var payoutAmount = vendor.WalletBalance;
        var tdsAmount = Math.Round(payoutAmount * _ledgerService.TdsRate, 2, MidpointRounding.AwayFromZero);
        var netAmount = payoutAmount - tdsAmount;

        // Create payout request record
        var payoutRequest = PayoutRequest.CreateForVendor(
            vendor.Id,
            payoutAmount,
            tdsAmount,
            vendor.BankAccountNumber!,
            vendor.BankIfsc);
        _context.PayoutRequests.Add(payoutRequest);

        // Debit the vendor's wallet
        vendor.DebitWallet(payoutAmount);

        await _context.SaveChangesAsync(ct);

        // Execute the payout via the provider
        var result = await _payoutService.SendBankPayoutAsync(
            netAmount,
            vendor.BankAccountNumber!,
            vendor.BankIfsc!,
            vendor.BankAccountName,
            purpose: "vendor_payout",
            ct: ct);

        if (result.Success)
        {
            payoutRequest.MarkProcessing(result.ProviderPayoutId!);
            if (result.UtrNumber is not null)
                payoutRequest.MarkCompleted(result.UtrNumber);

            // Record the double-entry ledger
            var ledgerTxnId = await _ledgerService.RecordVendorPayoutAsync(
                payoutRequest.Id, vendor.Id, payoutAmount, tdsAmount, ct);
            payoutRequest.RecordLedgerTransaction(ledgerTxnId);

            await _context.SaveChangesAsync(ct);

            // Notify the vendor
            _ = _notifications.SendPushToVendorAsync(
                vendor.Id,
                "Payout Processed",
                $"₹{netAmount.ToString("F0", CultureInfo.InvariantCulture)} has been transferred to your bank account. UTR: {result.UtrNumber ?? "Pending"}",
                dataPayload: new()
                {
                    ["type"] = "payout_completed",
                    ["amount"] = netAmount.ToString("F2", CultureInfo.InvariantCulture),
                    ["utr"] = result.UtrNumber ?? ""
                },
                cancellationToken: ct);

            _logger.PayoutCompleted("Vendor", vendor.Id, netAmount, result.UtrNumber);
        }
        else
        {
            payoutRequest.MarkFailed(result.FailureReason ?? "Unknown error");

            // Refund the wallet balance since payout failed
            vendor.CreditWallet(payoutAmount);

            await _context.SaveChangesAsync(ct);

            // Notify the vendor about the failure
            _ = _notifications.SendPushToVendorAsync(
                vendor.Id,
                "Payout Failed",
                $"Your payout of ₹{netAmount.ToString("F0", CultureInfo.InvariantCulture)} could not be processed. Please verify your bank details. Balance retained in wallet.",
                dataPayload: new()
                {
                    ["type"] = "payout_failed",
                    ["reason"] = result.FailureReason ?? ""
                },
                cancellationToken: ct);

            _logger.PayoutFailed("Vendor", vendor.Id, result.FailureReason);
        }
    }

    private async Task ProcessSingleDriverPayoutAsync(Driver driver, decimal payoutAmount, CancellationToken ct)
    {
        var payoutRequest = PayoutRequest.CreateForDriver(
            driver.Id,
            payoutAmount,
            driver.UpiId);
        _context.PayoutRequests.Add(payoutRequest);

        await _context.SaveChangesAsync(ct);

        var result = await _payoutService.SendUpiPayoutAsync(
            payoutAmount,
            driver.UpiId!,
            purpose: "driver_payout",
            ct: ct);

        if (result.Success)
        {
            payoutRequest.MarkProcessing(result.ProviderPayoutId!);
            if (result.UtrNumber is not null)
                payoutRequest.MarkCompleted(result.UtrNumber);

            var ledgerTxnId = await _ledgerService.RecordDriverPayoutAsync(
                payoutRequest.Id, driver.Id, payoutAmount, ct);
            payoutRequest.RecordLedgerTransaction(ledgerTxnId);

            await _context.SaveChangesAsync(ct);

            _logger.PayoutCompleted("Driver", driver.Id, payoutAmount, result.UtrNumber);
        }
        else
        {
            payoutRequest.MarkFailed(result.FailureReason ?? "Unknown error");
            await _context.SaveChangesAsync(ct);

            _logger.PayoutFailed("Driver", driver.Id, result.FailureReason);
        }
    }

    /// <summary>
    /// Handles a payout.reversed webhook from RazorpayX.
    /// Rolls back the payout, credits the vendor's wallet back, and
    /// flags the vendor profile for bank detail update.
    /// </summary>
    public async Task HandlePayoutReversalAsync(
        string providerPayoutId,
        string reversalReason,
        CancellationToken ct = default)
    {
        var payout = await _context.PayoutRequests
            .FirstOrDefaultAsync(p => p.ProviderPayoutId == providerPayoutId, ct);

        if (payout is null)
        {
            _logger.LogWarning("Payout reversal for unknown provider ID: {ProviderPayoutId}", providerPayoutId);
            return;
        }

        if (payout.Status == PayoutStatus.Failed)
            return; // Already marked as failed

        payout.MarkFailed($"Reversed: {reversalReason}");

        // If it's a vendor payout, credit the wallet back
        if (payout.RecipientType == PayoutRecipientType.Vendor)
        {
            var vendor = await _context.Vendors.FirstOrDefaultAsync(v => v.Id == payout.RecipientId, ct);
            if (vendor is not null)
            {
                vendor.CreditWallet(payout.Amount);
                vendor.MarkBankVerificationFailed();

                _ = _notifications.SendPushToVendorAsync(
                    vendor.Id,
                    "Payout Reversed — Update Bank Details",
                    $"Your payout of ₹{payout.NetAmount:F0} was reversed: {reversalReason}. Please update your bank details. Balance restored to wallet.",
                    dataPayload: new()
                    {
                        ["type"] = "payout_reversed",
                        ["reason"] = reversalReason
                    },
                    cancellationToken: ct);
            }
        }

        await _context.SaveChangesAsync(ct);
        _logger.PayoutReversed(payout.Id, reversalReason);
    }
}

internal static partial class SettlementLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Daily payouts processed: {Type} — {Count} payouts")]
    public static partial void DailyPayoutsProcessed(this ILogger logger, string type, int count);

    [LoggerMessage(Level = LogLevel.Information, Message = "Payout completed: {Type} {RecipientId} — ₹{Amount}, UTR: {Utr}")]
    public static partial void PayoutCompleted(this ILogger logger, string type, Guid recipientId, decimal amount, string? utr);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Payout failed: {Type} {RecipientId} — {Reason}")]
    public static partial void PayoutFailed(this ILogger logger, string type, Guid recipientId, string? reason);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Payout reversed: {PayoutId} — {Reason}")]
    public static partial void PayoutReversed(this ILogger logger, Guid payoutId, string reason);
}
