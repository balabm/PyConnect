namespace PondyConnect.Application.Features.Fraud;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Detects fraudulent consumer behaviour by tracking post-assignment ride
/// cancellations. When a consumer cancels 3 or more rides after a driver has
/// been assigned within a 24-hour window, a <see cref="ConsumerFlag"/> is
/// created with <c>CodRestricted = true</c> for 48 hours and a shadow-ban
/// may be applied.
/// </summary>
public sealed class FraudDetectionService : IFraudDetectionService
{
    /// <summary>Minimum post-assignment cancellations in 24h to trigger a flag.</summary>
    public const int CancellationThreshold = 3;

    /// <summary>Duration of the COD restriction once the threshold is breached.</summary>
    public static readonly TimeSpan CodRestrictionDuration = TimeSpan.FromHours(48);

    /// <summary>Rolling window for counting post-assignment cancellations.</summary>
    public static readonly TimeSpan CancellationWindow = TimeSpan.FromHours(24);

    private readonly IApplicationDbContext _context;
    private readonly ILogger<FraudDetectionService> _logger;

    public FraudDetectionService(IApplicationDbContext context, ILogger<FraudDetectionService> logger)
    {
        _context = context;
        _logger = logger;
    }

    public async Task RecordCancellationAsync(string consumerId, string rideId)
    {
        if (!Guid.TryParse(consumerId, out var userGuid))
            return;

        var cutoff = DateTimeOffset.UtcNow - CancellationWindow;

        // Count rides cancelled by the rider after a driver was assigned
        // within the rolling 24-hour window.
        var recentPostAssignmentCancellations = await _context.RideRequests
            .AsNoTracking()
            .Where(r => r.UserId == userGuid
                && r.Status == RideStatus.Cancelled
                && r.DriverId.HasValue
                && r.CancelledAt.HasValue
                && r.CancelledAt.Value >= cutoff)
            .ToListAsync();

        var count = recentPostAssignmentCancellations.Count;

        _logger.LogInformation(
            "Consumer {ConsumerId} has {Count} post-assignment cancellations in the last 24h (ride {RideId}).",
            consumerId, count, rideId);

        if (count >= CancellationThreshold)
        {
            await ApplyCodRestrictionAsync(consumerId, count);
        }
    }

    public async Task EvaluateConsumerAsync(string consumerId)
    {
        if (!Guid.TryParse(consumerId, out var userGuid))
            return;

        var cutoff = DateTimeOffset.UtcNow - CancellationWindow;

        var count = await _context.RideRequests
            .AsNoTracking()
            .CountAsync(r => r.UserId == userGuid
                && r.Status == RideStatus.Cancelled
                && r.DriverId.HasValue
                && r.CancelledAt.HasValue
                && r.CancelledAt.Value >= cutoff);

        if (count >= CancellationThreshold)
        {
            await ApplyCodRestrictionAsync(consumerId, count);
            await ApplyShadowBanAsync(consumerId, count);
        }
    }

    public async Task<bool> IsCodRestrictedAsync(string consumerId)
    {
        var now = DateTimeOffset.UtcNow;
        return await _context.ConsumerFlags
            .AsNoTracking()
            .AnyAsync(f => f.ConsumerId == consumerId
                && f.CodRestricted
                && (f.ExpiresAt == null || f.ExpiresAt > now));
    }

    public async Task<bool> IsShadowBannedAsync(string consumerId)
    {
        var now = DateTimeOffset.UtcNow;
        return await _context.ConsumerFlags
            .AsNoTracking()
            .AnyAsync(f => f.ConsumerId == consumerId
                && f.ShadowBanned
                && (f.ExpiresAt == null || f.ExpiresAt > now));
    }

    // ── Helpers ──

    private async Task ApplyCodRestrictionAsync(string consumerId, int cancellationCount)
    {
        // Avoid duplicate flags: if an active COD restriction already exists, skip.
        if (await IsCodRestrictedAsync(consumerId))
            return;

        var flag = ConsumerFlag.Create(
            consumerId: consumerId,
            flagType: ConsumerFlagType.HighCancellationRate,
            reason: $"Consumer cancelled {cancellationCount} rides after driver assignment within 24 hours.",
            shadowBanned: false,
            codRestricted: true,
            expiresAt: DateTimeOffset.UtcNow + CodRestrictionDuration);

        _context.ConsumerFlags.Add(flag);
        await _context.SaveChangesAsync();

        _logger.LogWarning(
            "COD restriction applied to consumer {ConsumerId} for {Hours}h due to {Count} post-assignment cancellations.",
            consumerId, CodRestrictionDuration.TotalHours, cancellationCount);
    }

    private async Task ApplyShadowBanAsync(string consumerId, int cancellationCount)
    {
        if (await IsShadowBannedAsync(consumerId))
            return;

        var flag = ConsumerFlag.Create(
            consumerId: consumerId,
            flagType: ConsumerFlagType.HighCancellationRate,
            reason: $"Shadow-ban applied: {cancellationCount} post-assignment cancellations within 24 hours.",
            shadowBanned: true,
            codRestricted: false,
            expiresAt: DateTimeOffset.UtcNow + CodRestrictionDuration);

        _context.ConsumerFlags.Add(flag);
        await _context.SaveChangesAsync();

        _logger.LogWarning(
            "Shadow-ban applied to consumer {ConsumerId} due to {Count} post-assignment cancellations.",
            consumerId, cancellationCount);
    }
}
