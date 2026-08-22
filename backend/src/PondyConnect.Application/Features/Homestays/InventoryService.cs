namespace PondyConnect.Application.Features.Homestays;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Manages hard inventory locks for homestay rooms and scooter rentals.
/// When user A selects dates, a Pending_Lock is placed with a 10-minute
/// expiration. If user B tries to select the same dates, the UI blocks
/// them. If user A fails to pay within 10 minutes, a background worker
/// releases the lock back to the public pool.
/// </summary>
public sealed class InventoryService
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<InventoryService> _logger;

    /// <summary>
    /// The default duration for a pending inventory lock.
    /// </summary>
    public static readonly TimeSpan DefaultLockDuration = TimeSpan.FromMinutes(10);

    public InventoryService(IApplicationDbContext context, ILogger<InventoryService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Places a pending lock on the specified dates for a homestay.
    /// Called when the user selects dates on the calendar — before
    /// they proceed to payment. If any date in the range is already
    /// booked or has an active pending lock by a different user,
    /// throws InvalidOperationException.
    /// </summary>
    public async Task PlacePendingLockAsync(
        Guid homestayId,
        DateOnly checkIn,
        DateOnly checkOut,
        Guid userId,
        TimeSpan? lockDuration = null,
        CancellationToken ct = default)
    {
        var duration = lockDuration ?? DefaultLockDuration;

        var entries = await _context.RoomAvailabilities
            .Where(r => r.HomestayId == homestayId && r.Date >= checkIn && r.Date < checkOut)
            .ToListAsync(ct);

        if (entries.Count == 0)
            throw new InvalidOperationException("No availability entries found for the selected dates.");

        // Check for conflicts before placing any locks (atomic).
        foreach (var entry in entries)
        {
            entry.ClearExpiredPendingLock();
            if (entry.IsBooked)
                throw new InvalidOperationException("Selected dates are no longer available.");
            if (entry.HasActivePendingLock && entry.PendingLockedByUserId != userId)
                throw new InvalidOperationException("Some dates are temporarily held by another user. Please try again shortly.");
        }

        // Place the lock on all dates.
        foreach (var entry in entries)
        {
            entry.PlacePendingLock(userId, duration);
        }

        await _context.SaveChangesAsync(ct);
        _logger.PendingLockPlaced(homestayId, checkIn, checkOut, userId, duration);
    }

    /// <summary>
    /// Releases a pending lock on the specified dates. Called when
    /// the user navigates away from the booking screen without paying.
    /// </summary>
    public async Task ReleasePendingLockAsync(
        Guid homestayId,
        DateOnly checkIn,
        DateOnly checkOut,
        Guid userId,
        CancellationToken ct = default)
    {
        var entries = await _context.RoomAvailabilities
            .Where(r => r.HomestayId == homestayId && r.Date >= checkIn && r.Date < checkOut)
            .ToListAsync(ct);

        foreach (var entry in entries)
        {
            entry.ReleasePendingLock(userId);
        }

        await _context.SaveChangesAsync(ct);
        _logger.PendingLockReleased(homestayId, checkIn, checkOut, userId);
    }

    /// <summary>
    /// Releases all expired pending locks across all homestays.
    /// Called by a background worker (hosted service) that runs
    /// periodically to clean up stale locks.
    /// </summary>
    public async Task<int> ReleaseExpiredLocksAsync(CancellationToken ct = default)
    {
        var now = DateTimeOffset.UtcNow;

        var expiredEntries = await _context.RoomAvailabilities
            .Where(r => r.PendingLockUntil != null && r.PendingLockUntil <= now && !r.IsBooked)
            .ToListAsync(ct);

        if (expiredEntries.Count == 0)
            return 0;

        foreach (var entry in expiredEntries)
        {
            entry.ClearExpiredPendingLock();
        }

        await _context.SaveChangesAsync(ct);
        _logger.ExpiredLocksReleased(expiredEntries.Count);
        return expiredEntries.Count;
    }
}

internal static partial class InventoryServiceLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Pending lock placed for homestay {HomestayId}: {CheckIn} to {CheckOut} by user {UserId} for {Duration}")]
    public static partial void PendingLockPlaced(this ILogger logger, Guid homestayId, DateOnly checkIn, DateOnly checkOut, Guid userId, TimeSpan duration);

    [LoggerMessage(Level = LogLevel.Information, Message = "Pending lock released for homestay {HomestayId}: {CheckIn} to {CheckOut} by user {UserId}")]
    public static partial void PendingLockReleased(this ILogger logger, Guid homestayId, DateOnly checkIn, DateOnly checkOut, Guid userId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Released {Count} expired pending locks")]
    public static partial void ExpiredLocksReleased(this ILogger logger, int count);
}
