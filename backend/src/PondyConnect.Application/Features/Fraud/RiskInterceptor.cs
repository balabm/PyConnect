namespace PondyConnect.Application.Features.Fraud;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

/// <summary>
/// Provides interception logic for discovery and checkout endpoints.
/// Shadow-banned users see empty feeds; COD-disabled users cannot select cash.
/// </summary>
public sealed class RiskInterceptor
{
    private readonly IApplicationDbContext _context;
    private readonly ILogger<RiskInterceptor> _logger;

    public RiskInterceptor(
        IApplicationDbContext context,
        ILogger<RiskInterceptor> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Returns true if the user is shadow-banned and should see empty discovery feeds.
    /// </summary>
    public async Task<bool> IsShadowBannedAsync(Guid? userId, CancellationToken ct = default)
    {
        if (userId is null || userId == Guid.Empty)
            return false;

        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId.Value)
            .Select(u => new { u.IsShadowBanned, u.TrustScore })
            .FirstOrDefaultAsync(ct);

        if (user is null)
            return false;

        if (user.IsShadowBanned || user.TrustScore < RiskScoringService.ShadowBanThreshold)
        {
            _logger.LogInformation(
                "Shadow-ban intercept: user {UserId} sees empty feed (score {Score})",
                userId, user.TrustScore);
            return true;
        }

        return false;
    }

    /// <summary>
    /// Returns true if the user is COD-disabled and should not see cash as a payment option.
    /// </summary>
    public async Task<bool> IsCodDisabledAsync(Guid? userId, CancellationToken ct = default)
    {
        if (userId is null || userId == Guid.Empty)
            return false;

        var user = await _context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId.Value)
            .Select(u => new { u.IsCodDisabled, u.TrustScore })
            .FirstOrDefaultAsync(ct);

        if (user is null)
            return false;

        return user.IsCodDisabled || user.TrustScore < RiskScoringService.CodDisableThreshold;
    }
}
