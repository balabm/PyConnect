namespace PondyConnect.Api.Controllers;

using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Support;
using PondyConnect.Domain.Enums;
using PondyConnect.Infrastructure.Configuration;
using PondyConnect.Infrastructure.Services;

[ApiController]
[Route("api/whatsapp/webhook")]
public sealed class WhatsAppWebhookController : ControllerBase
{
    private readonly WhatsAppHttpClient _whatsappClient;
    private readonly WhatsAppOptions _options;
    private readonly IApplicationDbContext _context;
    private readonly MessageReceiverService _messageReceiver;
    private readonly ILogger<WhatsAppWebhookController> _logger;

    public WhatsAppWebhookController(
        WhatsAppHttpClient whatsappClient,
        IOptions<WhatsAppOptions> options,
        IApplicationDbContext context,
        MessageReceiverService messageReceiver,
        ILogger<WhatsAppWebhookController> logger)
    {
        _whatsappClient = whatsappClient;
        _options = options.Value;
        _context = context;
        _messageReceiver = messageReceiver;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public IActionResult VerifyWebhook(
        [FromQuery] string? hubMode,
        [FromQuery] string? hubVerifyToken,
        [FromQuery] string? hubChallenge)
    {
        if (hubMode != "subscribe" || hubVerifyToken != _options.WebhookVerifyToken)
            return Forbid();

        return Ok(hubChallenge);
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ReceiveWebhook(CancellationToken cancellationToken)
    {
        using var reader = new StreamReader(Request.Body);
        var rawBody = await reader.ReadToEndAsync(cancellationToken);

        var signature = Request.Headers["X-Hub-Signature-256"].FirstOrDefault()
            ?? Request.Headers["X-Hub-Signature"].FirstOrDefault();

        if (!_whatsappClient.VerifySignature(rawBody, signature))
        {
#pragma warning disable CA1848
            _logger.LogWarning("WhatsApp webhook signature verification failed");
#pragma warning restore CA1848
            return Unauthorized(new { Message = "Invalid signature" });
        }

        try
        {
            using var doc = JsonDocument.Parse(rawBody);
            var root = doc.RootElement;

            if (!root.TryGetProperty("entry", out var entryArray) || entryArray.GetArrayLength() == 0)
                return Ok(new { Status = "ignored" });

            foreach (var entry in entryArray.EnumerateArray())
            {
                if (!entry.TryGetProperty("changes", out var changes))
                    continue;

                foreach (var change in changes.EnumerateArray())
                {
                    if (!change.TryGetProperty("value", out var value))
                        continue;

                    if (!value.TryGetProperty("messages", out var messages) || messages.GetArrayLength() == 0)
                        continue;

                    foreach (var message in messages.EnumerateArray())
                    {
                        var fromPhone = message.TryGetProperty("from", out var fromEl)
                            ? fromEl.GetString() ?? ""
                            : "";

                        var messageText = "";
                        if (message.TryGetProperty("text", out var textEl)
                            && textEl.TryGetProperty("body", out var bodyEl))
                        {
                            messageText = bodyEl.GetString() ?? "";
                        }

                        if (string.IsNullOrWhiteSpace(fromPhone) || string.IsNullOrWhiteSpace(messageText))
                            continue;

                        await ProcessWhatsAppMessageAsync(fromPhone, messageText, cancellationToken);
                    }
                }
            }
        }
        catch (Exception ex)
        {
#pragma warning disable CA1848
            _logger.LogError(ex, "Error processing WhatsApp webhook");
#pragma warning restore CA1848
        }

        return Ok(new { Status = "processed" });
    }

    private async Task ProcessWhatsAppMessageAsync(
        string fromPhone,
        string messageText,
        CancellationToken cancellationToken)
    {
        var normalizedPhone = fromPhone.StartsWith('+') ? fromPhone : "+" + fromPhone;

        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Phone == normalizedPhone || u.Phone == fromPhone, cancellationToken);

        if (user is null)
        {
#pragma warning disable CA1848
            _logger.LogInformation("WhatsApp message from unknown number: {Phone}", fromPhone);
#pragma warning restore CA1848
            await _whatsappClient.SendTextMessageAsync(
                fromPhone,
                "Hi! I'm PondyConnect's assistant. Please download the PondyConnect app to get started with rides, food, stays, and more in Pondicherry!",
                cancellationToken);
            return;
        }

        var result = await _messageReceiver.ReceiveMessageAsync(
            user.Id,
            messageText,
            TicketSource.WhatsApp,
            cancellationToken);

        await _whatsappClient.SendTextMessageAsync(fromPhone, result.AiReply, cancellationToken);

        if (result.IsCritical)
        {
#pragma warning disable CA1848
            _logger.LogWarning("Critical issue detected from WhatsApp user {UserId}: {Intent}",
                user.Id, result.DetectedIntent);
#pragma warning restore CA1848
        }
    }
}
