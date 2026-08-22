namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Fraud;

/// <summary>
/// Admin endpoints for managing user risk scores and fraud flags.
/// </summary>
[ApiController]
[Route("api/admin/risk")]
[Authorize(Roles = "Admin")]
public sealed class AdminRiskController : ControllerBase
{
    private readonly RiskScoringService _riskScoringService;

    public AdminRiskController(RiskScoringService riskScoringService)
    {
        _riskScoringService = riskScoringService;
    }

    /// <summary>
    /// Gets a user's trust score and restriction status.
    /// </summary>
    [HttpGet("{userId:guid}")]
    [ProducesResponseType(typeof(RiskScoreResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RiskScoreResponse>> GetRiskScore(Guid userId, CancellationToken ct)
    {
        var score = await _riskScoringService.GetRiskScoreAsync(userId, ct);
        if (score is null)
            return NotFound(new { Message = "User not found." });

        return Ok(score);
    }

    /// <summary>
    /// Admin override to set a user's absolute trust score.
    /// </summary>
    [HttpPut("{userId:guid}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetTrustScore(
        Guid userId,
        [FromBody] SetTrustScoreRequest request,
        CancellationToken ct)
    {
        try
        {
            await _riskScoringService.SetTrustScoreAsync(userId, request.Score, ct);
            return NoContent();
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "User not found." });
        }
    }

    /// <summary>
    /// Applies a trust score penalty for a refunded order.
    /// </summary>
    [HttpPost("{userId:guid}/penalty/refund")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ApplyRefundPenalty(Guid userId, CancellationToken ct)
    {
        await _riskScoringService.RecordFoodRefundAsync(userId, ct);
        return NoContent();
    }

    /// <summary>
    /// Applies a trust score penalty for a cancelled ride.
    /// </summary>
    [HttpPost("{userId:guid}/penalty/cancellation")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> ApplyCancellationPenalty(Guid userId, CancellationToken ct)
    {
        await _riskScoringService.RecordRideCancellationAsync(userId, ct);
        return NoContent();
    }

    /// <summary>
    /// Awards trust score points for a 5-star trip.
    /// </summary>
    [HttpPost("{userId:guid}/reward/five-star")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> AwardFiveStar(Guid userId, CancellationToken ct)
    {
        await _riskScoringService.RecordFiveStarTripAsync(userId, ct);
        return NoContent();
    }
}

public sealed record SetTrustScoreRequest(int Score);
