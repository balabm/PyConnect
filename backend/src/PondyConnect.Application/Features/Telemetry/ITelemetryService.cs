namespace PondyConnect.Application.Features.Telemetry;

public interface ITelemetryService
{
    ValueTask LogAsync(
        Guid? userId,
        string sessionId,
        string eventName,
        string? payloadJson = null,
        CancellationToken cancellationToken = default);
}
