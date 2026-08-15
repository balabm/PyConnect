namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Features.Payments;

/// <summary>
/// Dedicated Razorpay webhook receiver. Reads the raw request body as a
/// string so the HMAC-SHA256 signature can be verified against the exact
/// bytes Razorpay signed. The existing <see cref="PaymentsController"/>
/// keeps the authenticated initiate/refund endpoints; this controller is
/// anonymous because Razorpay calls it server-to-server without a JWT.
/// </summary>
[ApiController]
[Route("api/payments/webhook")]
[AllowAnonymous]
public sealed class PaymentsWebhookController : ControllerBase
{
    private readonly IMediator _mediator;

    public PaymentsWebhookController(IMediator mediator)
    {
        _mediator = mediator;
    }

    [HttpPost]
    [ProducesResponseType(typeof(VerifyPaymentWebhookResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> Handle(
        [FromHeader(Name = "X-Razorpay-Signature")] string? signature,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(signature))
            return BadRequest(new { Message = "Missing X-Razorpay-Signature header." });

        // Read the raw body — Razorpay signs the exact bytes, so we must not
        // let the model binder re-serialize or alter the JSON.
        Request.EnableBuffering();
        using var reader = new StreamReader(
            Request.Body,
            leaveOpen: false);
        var payload = await reader.ReadToEndAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(payload))
            return BadRequest(new { Message = "Empty webhook body." });

        var command = new VerifyPaymentWebhookCommand(payload, signature);
        var result = await _mediator.Send(command, cancellationToken);

        if (!result.Success)
            return BadRequest(result); // 400 on verification failure — reject invalid webhooks

        return Ok(result);
    }
}
