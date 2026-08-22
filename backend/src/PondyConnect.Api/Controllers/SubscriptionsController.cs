namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Subscriptions;

/// <summary>
/// PY Prime subscription management endpoints.
/// </summary>
[ApiController]
[Route("api/subscriptions")]
[Authorize]
public sealed class SubscriptionsController : ControllerBase
{
    private readonly SubscriptionService _subscriptionService;
    private readonly ICurrentUserService _currentUser;

    public SubscriptionsController(
        SubscriptionService subscriptionService,
        ICurrentUserService currentUser)
    {
        _subscriptionService = subscriptionService;
        _currentUser = currentUser;
    }

    /// <summary>
    /// Gets the current user's PY Prime status.
    /// </summary>
    [HttpGet("status")]
    [ProducesResponseType(typeof(PrimeStatusResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<PrimeStatusResponse>> GetStatus(CancellationToken ct)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException();
        var status = await _subscriptionService.GetPrimeStatusAsync(userId, ct);
        return Ok(status);
    }

    /// <summary>
    /// Activates PY Prime after successful Razorpay payment.
    /// Called by the client after the subscription payment is verified.
    /// </summary>
    [HttpPost("activate")]
    [ProducesResponseType(typeof(PrimeStatusResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<PrimeStatusResponse>> Activate(
        [FromBody] ActivateSubscriptionRequest request,
        CancellationToken ct)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException();
        await _subscriptionService.ActivatePrimeAsync(userId, request.PaymentReference, ct);
        var status = await _subscriptionService.GetPrimeStatusAsync(userId, ct);
        return Ok(status);
    }

    /// <summary>
    /// Handles Razorpay eMandate renewal failure webhook.
    /// Starts the 3-day grace period before revoking Prime.
    /// </summary>
    [HttpPost("renewal-failed")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> RenewalFailed(
        [FromBody] RenewalFailedRequest request,
        CancellationToken ct)
    {
        await _subscriptionService.HandleRenewalFailureAsync(request.UserId, ct);
        return NoContent();
    }
}

public sealed record ActivateSubscriptionRequest(string? PaymentReference);

public sealed record RenewalFailedRequest(Guid UserId);
