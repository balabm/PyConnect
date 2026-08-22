namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Payments;
using PondyConnect.Application.Features.Wallet;

[ApiController]
[Route("api/payments")]
[Authorize]
public sealed class PaymentsController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly ICurrentUserService _currentUser;
    private readonly LoyaltyService _loyalty;

    public PaymentsController(IMediator mediator, ICurrentUserService currentUser, LoyaltyService loyalty)
    {
        _mediator = mediator;
        _currentUser = currentUser;
        _loyalty = loyalty;
    }

    [HttpPost]
    [HttpPost("create-order")]
    [ProducesResponseType(typeof(InitiatePaymentResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<InitiatePaymentResponse>> Initiate(
        [FromBody] InitiatePaymentCommand command,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return CreatedAtAction(nameof(Initiate), new { id = result.PaymentId }, result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    // NOTE: The webhook endpoint has been moved to PaymentsWebhookController,
    // which reads the raw request body for correct HMAC signature verification.

    [HttpPost("{paymentId:guid}/refund")]
    [ProducesResponseType(typeof(RefundPaymentResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RefundPaymentResponse>> Refund(
        Guid paymentId,
        [FromBody] RefundPaymentCommand command,
        CancellationToken cancellationToken = default)
    {
        if (command.PaymentId != paymentId)
            return BadRequest(new { Message = "Payment ID mismatch." });

        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return NotFound(new { Message = "Payment not found." });
        }
    }

    /// <summary>
    /// Verifies a Razorpay checkout payment signature submitted by the client
    /// after a successful payment. On a valid signature the internal payment
    /// record is marked as captured.
    /// </summary>
    [HttpPost("verify")]
    [ProducesResponseType(typeof(VerifyPaymentResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<VerifyPaymentResponse>> Verify(
        [FromBody] VerifyPaymentRequest request,
        CancellationToken cancellationToken = default)
    {
        var command = new VerifyPaymentCommand(
            request.PaymentId,
            request.RazorpayPaymentId,
            request.RazorpayOrderId,
            request.RazorpaySignature);

        try
        {
            var result = await _mediator.Send(command, cancellationToken);
            if (!result.Verified)
                return BadRequest(new { Message = result.ErrorMessage ?? "Signature verification failed." });
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return NotFound(new { Message = "Payment not found." });
        }
    }

    // ── PY Coins Loyalty Endpoints ──

    /// <summary>
    /// Returns the user's current PY Coin balance.
    /// </summary>
    [HttpGet("loyalty/balance")]
    [ProducesResponseType(typeof(LoyaltyBalanceResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<LoyaltyBalanceResponse>> GetCoinBalance(CancellationToken ct = default)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        var balance = await _loyalty.GetCoinBalanceAsync(userId.Value, ct);
        return Ok(new LoyaltyBalanceResponse(balance));
    }

    /// <summary>
    /// Redeems PY Coins against a platform fee. 1 PY Coin = ₹1.
    /// Called during checkout when the user toggles "Use PY Coins".
    /// Returns the discount amount applied.
    /// </summary>
    [HttpPost("loyalty/redeem")]
    [ProducesResponseType(typeof(RedeemCoinsResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RedeemCoinsResponse>> RedeemCoins(
        [FromBody] RedeemCoinsRequest request,
        CancellationToken ct = default)
    {
        var userId = _currentUser.UserId;
        if (userId is null || userId == Guid.Empty)
            return Unauthorized(new { Message = "User not authenticated." });

        try
        {
            var discount = await _loyalty.RedeemCoinsAsync(userId.Value, request.Coins, ct);
            return Ok(new RedeemCoinsResponse(discount, request.Coins, "PY Coins redeemed successfully."));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }
}

public sealed record LoyaltyBalanceResponse(int PyCoins);
public sealed record RedeemCoinsRequest(int Coins);
public sealed record RedeemCoinsResponse(decimal DiscountApplied, int CoinsRedeemed, string Message);

public sealed record VerifyPaymentRequest(
    Guid PaymentId,
    string RazorpayPaymentId,
    string RazorpayOrderId,
    string RazorpaySignature);