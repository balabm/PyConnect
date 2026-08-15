namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class DriverPayoutService
{
    public const decimal InstantPayoutFee = 5m;
    public const decimal ScheduledPayoutThreshold = 100m;

    private readonly IApplicationDbContext _context;
    private readonly ILogger<DriverPayoutService> _logger;

    public DriverPayoutService(IApplicationDbContext context, ILogger<DriverPayoutService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task<decimal> GetBalanceAsync(Guid driverId, CancellationToken ct = default)
    {
        var entries = await _context.DriverLedgerEntries.AsNoTracking()
            .Where(e => e.DriverId == driverId)
            .ToListAsync(ct);

        return entries.Sum(e => e.Amount);
    }

    public async Task<InstantPayoutResult> RequestInstantPayout(Guid driverId, CancellationToken ct = default)
    {
        var balance = await GetBalanceAsync(driverId, ct);

        if (balance <= 0m)
            return new InstantPayoutResult(false, 0m, InstantPayoutFee, balance, "Insufficient balance for payout.");

        var payoutAmount = balance - InstantPayoutFee;
        if (payoutAmount <= 0m)
            return new InstantPayoutResult(false, 0m, InstantPayoutFee, balance, "Balance too low to cover payout fee.");

        await using var transaction = await _context.BeginTransactionAsync(ct);

        var withdrawal = DriverLedgerEntry.Create(driverId, -payoutAmount, LedgerTransactionType.Withdrawal, "INSTANT_PAYOUT");
        var fee = DriverLedgerEntry.Create(driverId, -InstantPayoutFee, LedgerTransactionType.Withdrawal, "INSTANT_PAYOUT_FEE");

        _context.DriverLedgerEntries.AddRange(withdrawal, fee);
        await _context.SaveChangesAsync(ct);

        if (transaction is not null)
            await transaction.CommitAsync(ct);

        _logger.InstantPayoutProcessed(driverId, payoutAmount, InstantPayoutFee);

        return new InstantPayoutResult(true, payoutAmount, InstantPayoutFee, 0m, "Instant payout processed successfully.");
    }

    public async Task<int> ProcessScheduledPayouts(CancellationToken ct = default)
    {
        var drivers = await _context.Drivers.AsNoTracking().ToListAsync(ct);
        var processed = 0;

        await using var transaction = await _context.BeginTransactionAsync(ct);

        foreach (var driver in drivers)
        {
            var balance = await GetBalanceAsync(driver.Id, ct);
            if (balance <= ScheduledPayoutThreshold)
                continue;

            var withdrawal = DriverLedgerEntry.Create(driver.Id, -balance, LedgerTransactionType.Withdrawal, "SCHEDULED_PAYOUT");
            _context.DriverLedgerEntries.Add(withdrawal);
            processed++;

            _logger.ScheduledPayoutProcessed(driver.Id, balance);
        }

        if (processed > 0)
            await _context.SaveChangesAsync(ct);

        if (transaction is not null)
            await transaction.CommitAsync(ct);

        return processed;
    }
}

internal static partial class DriverPayoutLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Instant payout processed for driver {DriverId}: ₹{Amount} (fee ₹{Fee})")]
    public static partial void InstantPayoutProcessed(this ILogger logger, Guid driverId, decimal amount, decimal fee);

    [LoggerMessage(Level = LogLevel.Information, Message = "Scheduled payout processed for driver {DriverId}: ₹{Amount} (no fee)")]
    public static partial void ScheduledPayoutProcessed(this ILogger logger, Guid driverId, decimal amount);
}

public sealed record InstantPayoutResult(
    bool Success,
    decimal Amount,
    decimal Fee,
    decimal NewBalance,
    string Message);
