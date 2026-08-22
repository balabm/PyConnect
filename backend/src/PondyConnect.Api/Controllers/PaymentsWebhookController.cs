namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Payments;
using PondyConnect.Application.Features.Settlement;
using System.Text.Json;

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
    private readonly SettlementService? _settlementService;
    private readonly ILogger<PaymentsWebhookController> _logger;

    public PaymentsWebhookController(IMediator mediator, ILogger<PaymentsWebhookController> logger)
    {
        _mediator = mediator;
        _settlementService = null;
        _logger = logger;
    }

    public PaymentsWebhookController(IMediator mediator, SettlementService settlementService, ILogger<PaymentsWebhookController> logger)
    {
        _mediator = mediator;
        _settlementService = settlementService;
        _logger = logger;
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

    /// <summary>
    /// RazorpayX payout webhook receiver. Handles payout.processed,
    /// payout.reversed, and payout.failed events. When a payout is
    /// reversed (bank account invalid/frozen), rolls back the vendor's
    /// wallet balance and flags their profile for bank detail update.
    /// </summary>
    [HttpPost("payout")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> HandlePayoutWebhook(
        [FromHeader(Name = "X-Razorpay-Signature")] string? signature,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(signature))
            return BadRequest(new { Message = "Missing X-Razorpay-Signature header." });

        Request.EnableBuffering();
        using var reader = new StreamReader(Request.Body, leaveOpen: false);
        var payload = await reader.ReadToEndAsync(cancellationToken);

        if (string.IsNullOrWhiteSpace(payload))
            return BadRequest(new { Message = "Empty webhook body." });

        try
        {
            var doc = JsonDocument.Parse(payload);
            var eventKey = doc.RootElement.TryGetProperty("event", out var eventEl) ? eventEl.GetString() : null;

            if (string.IsNullOrWhiteSpace(eventKey))
                return Ok(new { Message = "No event field in payload." });

            // Extract payout ID from the payload
            var payoutId = doc.RootElement
                .TryGetProperty("payload", out var payloadEl)
                && payloadEl.TryGetProperty("payout", out var payoutEl)
                && payoutEl.TryGetProperty("entity", out var entityEl)
                && entityEl.TryGetProperty("id", out var idEl)
                ? idEl.GetString() : null;

            if (payoutId is null)
                return Ok(new { Message = "No payout ID in payload." });

            _logger.LogInformation("RazorpayX payout webhook: {Event} for payout {PayoutId}", eventKey, payoutId);

            if (_settlementService is null)
                return Ok(new { Message = "Settlement service not configured." });

            // Handle reversal/failed events
            if (eventKey.Contains("reversed") || eventKey.Contains("failed"))
            {
                var reason = eventKey.Contains("reversed") ? "Bank reversed the payout" : "Payout failed at provider";
                await _settlementService.HandlePayoutReversalAsync(payoutId, reason, cancellationToken);
            }

            return Ok(new { Message = "Payout webhook processed.", Event = eventKey });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing payout webhook");
            return BadRequest(new { Message = "Failed to process webhook." });
        }
    }
}
