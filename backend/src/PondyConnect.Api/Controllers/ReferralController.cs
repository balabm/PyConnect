namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Referral;

[ApiController]
[Route("api/referrals")]
[Authorize]
public sealed class ReferralController : ControllerBase
{
    private readonly ReferralService _referralService;
    private readonly ICurrentUserService _currentUser;
    private readonly IApplicationDbContext _dbContext;

    public ReferralController(ReferralService referralService, ICurrentUserService currentUser, IApplicationDbContext dbContext)
    {
        _referralService = referralService;
        _currentUser = currentUser;
        _dbContext = dbContext;
    }

    /// <summary>
    /// Returns the authenticated user's referral code and stats.
    /// Used by the consumer app's "Invite Friends" screen.
    /// </summary>
    [HttpGet("me")]
    [ProducesResponseType(typeof(ReferralInfoResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<ReferralInfoResponse>> GetMyReferralInfo(CancellationToken ct)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var user = await _dbContext.Users.AsNoTracking()
            .FirstOrDefaultAsync(u => u.Id == userId, ct);

        var stats = await _referralService.GetStatsAsync(userId, ct);

        return Ok(new ReferralInfoResponse(
            user?.ReferralCode ?? "",
            stats.TotalReferred,
            stats.Completed,
            stats.Pending,
            stats.TotalEarned));
    }

    /// <summary>
    /// Applies a referral code during onboarding. Credits the welcome
    /// amount to the new user's wallet and creates a pending referral
    /// record for the referrer.
    /// </summary>
    [HttpPost("apply")]
    [ProducesResponseType(typeof(ApplyReferralResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<ApplyReferralResponse>> ApplyReferralCode(
        [FromBody] ApplyReferralRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return Unauthorized(new { Message = "User not authenticated." });

        try
        {
            var success = await _referralService.ProcessReferralCodeAsync(userId.Value, request.ReferralCode, ct);
            if (!success)
                return BadRequest(new { Message = "Invalid or already used referral code." });

            return Ok(new ApplyReferralResponse(true, "Welcome credit applied to your wallet!"));
        }
        catch (ArgumentException)
        {
            return BadRequest(new { Message = "Referral code is required." });
        }
    }
}

public sealed record ReferralInfoResponse(string ReferralCode, int TotalReferred, int Completed, int Pending, decimal TotalEarned);
public sealed record ApplyReferralRequest(string ReferralCode);
public sealed record ApplyReferralResponse(bool Success, string Message);
