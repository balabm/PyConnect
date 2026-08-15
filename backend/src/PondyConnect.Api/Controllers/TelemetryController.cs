namespace PondyConnect.Api.Controllers;

using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Telemetry;
using System.Text.Json;

[ApiController]
[Route("api/telemetry")]
[Authorize]
public sealed class TelemetryController : ControllerBase
{
    private readonly ITelemetryService _telemetryService;
    private readonly ICurrentUserService _currentUser;

    public TelemetryController(ITelemetryService telemetryService, ICurrentUserService currentUser)
    {
        _telemetryService = telemetryService;
        _currentUser = currentUser;
    }

    [HttpPost("log")]
    [ProducesResponseType(StatusCodes.Status202Accepted)]
    public async Task<IActionResult> LogEvents(
        [FromBody] LogEventsRequest request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        var sessionId = request.SessionId ?? Guid.NewGuid().ToString();

        foreach (var evt in request.Events)
        {
            var payloadJson = evt.Payload != null
                ? JsonSerializer.Serialize(evt.Payload)
                : null;

            await _telemetryService.LogAsync(
                userId,
                sessionId,
                evt.EventName,
                payloadJson,
                cancellationToken);
        }

        return Accepted(new { Status = "queued", Count = request.Events.Count });
    }
}

public sealed record LogEventsRequest(string? SessionId, List<LogEventEntry> Events);

public sealed record LogEventEntry(string EventName, object? Payload);
