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
    private readonly IPaymentGateway _paymentGateway;

    public SubscriptionsController(
        SubscriptionService subscriptionService,
        ICurrentUserService currentUser,
        IPaymentGateway paymentGateway)
    {
        _subscriptionService = subscriptionService;
        _currentUser = currentUser;
        _paymentGateway = paymentGateway;
    }

    /// <summary>
    /// Creates a Razorpay order for a PY Prime monthly subscription.
    /// The client completes checkout and calls <see cref="Activate"/> to
    /// activate Prime after successful payment.
    /// </summary>
    [HttpPost("create-order")]
    [ProducesResponseType(typeof(SubscriptionOrderResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<SubscriptionOrderResponse>> CreateOrder(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var receipt = $"prime-{userId.Value.ToString().Substring(0, 8)}-{DateTimeOffset.UtcNow.ToUnixTimeSeconds()}";
        var order = await _paymentGateway.CreateOrderAsync(
            SubscriptionService.MonthlyPrice, "INR", receipt, capture: true, cancellationToken: ct);

        if (!order.Success || order.OrderId is null)
            return BadRequest(new { Message = order.ErrorMessage ?? "Failed to create payment order." });

        return Ok(new SubscriptionOrderResponse(order.OrderId, SubscriptionService.MonthlyPrice));
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

public sealed record SubscriptionOrderResponse(string RazorpayOrderId, decimal Amount);
