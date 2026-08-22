namespace PondyConnect.Application.Features.Rental;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Handles rental deposit reconciliation: pre-rental condition photo
/// locks, late return overage billing, and damage penalty deductions
/// from the security deposit.
/// </summary>
public sealed class RentalDepositService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<RentalDepositService> _logger;

    public RentalDepositService(IApplicationDbContext context, ILogger<RentalDepositService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Records the pre-rental 4-angle condition photos (Front, Back,
    /// Left, Right, Odometer/Fuel). Creates an undeniable baseline
    /// for damage claims.
    /// </summary>
    public async Task RecordConditionPhotosAsync(
        Guid rentalId,
        Guid vendorId,
        string photosJson,
        CancellationToken ct = default)
    {
        var rental = await _context.ScooterRentals
            .FirstOrDefaultAsync(r => r.Id == rentalId, ct)
            ?? throw new InvalidOperationException("Rental not found.");

        if (rental.VendorId != vendorId)
            throw new UnauthorizedAccessException("Only the rental vendor can record condition photos.");

        rental.RecordConditionPhotos(photosJson);
        await _context.SaveChangesAsync(ct);

        _logger.ConditionPhotosRecorded(rentalId, vendorId);
    }

    /// <summary>
    /// Completes the rental return with late fees and damage penalties.
    /// Calculates the total penalty and determines how much to refund
    /// from the security deposit.
    /// </summary>
    public async Task<ReturnReconciliation> CompleteReturnAsync(
        Guid rentalId,
        Guid vendorId,
        int lateMinutes = 0,
        decimal damageAmount = 0m,
        string? returnConditionPhotosJson = null,
        CancellationToken ct = default)
    {
        var rental = await _context.ScooterRentals
            .FirstOrDefaultAsync(r => r.Id == rentalId, ct)
            ?? throw new InvalidOperationException("Rental not found.");

        if (rental.VendorId != vendorId)
            throw new UnauthorizedAccessException("Only the rental vendor can complete the return.");

        rental.CompleteReturn(lateMinutes, damageAmount, returnConditionPhotosJson);
        await _context.SaveChangesAsync(ct);

        _logger.ReturnCompleted(rentalId, rental.DepositPenalty, rental.DepositRefunded);

        return new ReturnReconciliation(
            rentalId,
            rental.SecurityDeposit,
            rental.DepositPenalty,
            rental.DepositRefunded,
            rental.TotalAmount);
    }
}

public sealed record ReturnReconciliation(
    Guid RentalId,
    decimal SecurityDeposit,
    decimal PenaltyDeducted,
    decimal DepositRefunded,
    decimal TotalAmount);

internal static partial class RentalDepositLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Condition photos recorded for rental {RentalId} by vendor {VendorId}")]
    public static partial void ConditionPhotosRecorded(this ILogger logger, Guid rentalId, Guid vendorId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Rental {RentalId} returned. Penalty: ₹{Penalty}, Refunded: ₹{Refunded}")]
    public static partial void ReturnCompleted(this ILogger logger, Guid rentalId, decimal penalty, decimal refunded);
}
