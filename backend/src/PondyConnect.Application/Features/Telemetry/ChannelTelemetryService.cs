namespace PondyConnect.Application.Features.Telemetry;

using System.Threading.Channels;
using PondyConnect.Domain.Entities;

public sealed class ChannelTelemetryService : ITelemetryService
{
    private readonly Channel<AppEventLog> _channel;

    public ChannelTelemetryService()
    {
        _channel = Channel.CreateUnbounded<AppEventLog>(new UnboundedChannelOptions
        {
            SingleReader = true,
            SingleWriter = false,
        });
    }

    public ChannelReader<AppEventLog> Reader => _channel.Reader;

    public ValueTask LogAsync(
        Guid? userId,
        string sessionId,
        string eventName,
        string? payloadJson = null,
        CancellationToken cancellationToken = default)
    {
        var log = AppEventLog.Create(userId, sessionId, eventName, payloadJson);
        return _channel.Writer.WriteAsync(log, cancellationToken);
    }
}
