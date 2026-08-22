namespace PondyConnect.Application.Features.Fraud;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using System.Globalization;

/// <summary>
/// Risk scoring sentinel that adjusts a user's TrustScore based on behaviour.
/// Every user starts at 100. Score adjustments:
///   - Cancelled ride post-dispatch: -5
///   - Refunded food order: -10
///   - Completed 5-star trip: +2
///
/// Consequences:
///   - TrustScore &lt; 40: COD disabled (must pre-pay)
///   - TrustScore &lt; 20: shadow-banned (no drivers/restaurants found)
/// </summary>
public sealed class RiskScoringService
{
    public const int InitialTrustScore = 100;
    public const int CodDisableThreshold = 40;
    public const int ShadowBanThreshold = 20;

    public const int PenaltyCancelledRide = -5;
    public const int PenaltyRefundedOrder = -10;
    public const int RewardFiveStarTrip = 2;

    private readonly IApplicationDbContext _context;
    private readonly ILogger<RiskScoringService> _logger;

    public RiskScoringService(
        IApplicationDbContext context,
        ILogger<RiskScoringService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Records a post-dispatch ride cancellation: -5 trust score.
    /// </summary>
    public async Task RecordRideCancellationAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await GetUserAsync(userId, ct);
        if (user is null) return;

        user.AdjustTrustScore(PenaltyCancelledRide);
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Trust score adjustment: user {UserId} -5 (ride cancellation). New score: {Score}",
            userId, user.TrustScore);

        await LogConsequenceAsync(user, ct);
    }

    /// <summary>
    /// Records a refunded food order: -10 trust score.
    /// </summary>
    public async Task RecordFoodRefundAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await GetUserAsync(userId, ct);
        if (user is null) return;

        user.AdjustTrustScore(PenaltyRefundedOrder);
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Trust score adjustment: user {UserId} -10 (food refund). New score: {Score}",
            userId, user.TrustScore);

        await LogConsequenceAsync(user, ct);
    }

    /// <summary>
    /// Records a completed 5-star trip: +2 trust score.
    /// </summary>
    public async Task RecordFiveStarTripAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await GetUserAsync(userId, ct);
        if (user is null) return;

        user.AdjustTrustScore(RewardFiveStarTrip);
        await _context.SaveChangesAsync(ct);

        _logger.LogInformation(
            "Trust score adjustment: user {UserId} +2 (5-star trip). New score: {Score}",
            userId, user.TrustScore);
    }

    /// <summary>
    /// Gets the user's current trust score and restriction status.
    /// </summary>
    public async Task<RiskScoreResponse?> GetRiskScoreAsync(Guid userId, CancellationToken ct = default)
    {
        var user = await _context.Users
            .AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        if (user is null) return null;

        return new RiskScoreResponse(
            user.TrustScore,
            user.IsCodDisabled,
            user.IsShadowBanned,
            user.TrustScoreUpdatedAt);
    }

    /// <summary>
    /// Admin override to set an absolute trust score.
    /// </summary>
    public async Task SetTrustScoreAsync(Guid userId, int score, CancellationToken ct = default)
    {
        var user = await GetUserAsync(userId, ct);
        if (user is null)
            throw new InvalidOperationException("User not found.");

        user.SetTrustScore(score);
        await _context.SaveChangesAsync(ct);

        _logger.LogWarning(
            "Admin override: user {UserId} trust score set to {Score}",
            userId, score);
    }

    private async Task<User?> GetUserAsync(Guid userId, CancellationToken ct)
    {
        return await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, ct);
    }

    private async Task LogConsequenceAsync(User user, CancellationToken ct)
    {
        if (user.IsCodDisabled && user.TrustScore is >= 35 and < 40)
        {
            _logger.LogWarning(
                "User {UserId} COD disabled (trust score {Score} < {Threshold})",
                user.Id, user.TrustScore, CodDisableThreshold);
        }

        if (user.IsShadowBanned && user.TrustScore is >= 15 and < 20)
        {
            _logger.LogWarning(
                "User {UserId} shadow-banned (trust score {Score} < {Threshold})",
                user.Id, user.TrustScore, ShadowBanThreshold);
        }

        await Task.CompletedTask;
    }
}

public sealed record RiskScoreResponse(
    int TrustScore,
    bool IsCodDisabled,
    bool IsShadowBanned,
    DateTimeOffset? TrustScoreUpdatedAt);
