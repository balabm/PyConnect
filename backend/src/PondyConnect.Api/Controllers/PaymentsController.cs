namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Payments;

[ApiController]
[Route("api/payments")]
[Authorize]
public sealed class PaymentsController : ControllerBase
{
    private readonly IMediator _mediator;

    public PaymentsController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
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
}

public sealed record VerifyPaymentRequest(
    Guid PaymentId,
    string RazorpayPaymentId,
    string RazorpayOrderId,
    string RazorpaySignature);