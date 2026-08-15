namespace PondyConnect.Application.Features.Telemetry;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

public sealed class TelemetryBatchProcessor : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TelemetryBatchProcessor> _logger;
    private readonly ChannelTelemetryService _telemetryService;
    private readonly TimeSpan _flushInterval = TimeSpan.FromSeconds(5);
    private const int MaxBatchSize = 100;

    public TelemetryBatchProcessor(
        IServiceProvider serviceProvider,
        ILogger<TelemetryBatchProcessor> logger,
        ChannelTelemetryService telemetryService)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
        _telemetryService = telemetryService;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var batch = new List<AppEventLog>(MaxBatchSize);

        while (!stoppingToken.IsCancellationRequested)
        {
            batch.Clear();
            var flushDeadline = DateTime.UtcNow + _flushInterval;

            try
            {
                while (batch.Count < MaxBatchSize && DateTime.UtcNow < flushDeadline)
                {
                    var remaining = flushDeadline - DateTime.UtcNow;
                    if (remaining <= TimeSpan.Zero) break;

                    using var cts = CancellationTokenSource.CreateLinkedTokenSource(stoppingToken);
                    cts.CancelAfter(remaining);

                    try
                    {
                        var hasItem = await _telemetryService.Reader.WaitToReadAsync(cts.Token);
                        if (!hasItem) break;

                        while (batch.Count < MaxBatchSize && _telemetryService.Reader.TryRead(out var item))
                        {
                            batch.Add(item);
                        }
                    }
                    catch (OperationCanceledException) when (!stoppingToken.IsCancellationRequested)
                    {
                        break;
                    }
                }

                if (batch.Count > 0)
                {
                    await FlushAsync(batch, stoppingToken);
                }
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.TelemetryBatchError(ex);
            }
        }

        if (batch.Count > 0)
        {
            try
            {
                await FlushAsync(batch, CancellationToken.None);
            }
            catch (Exception ex)
            {
                _logger.TelemetryBatchError(ex);
            }
        }
    }

    private async Task FlushAsync(List<AppEventLog> batch, CancellationToken cancellationToken)
    {
        using var scope = _serviceProvider.CreateScope();
        var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();

        await context.AppEventLogs.AddRangeAsync(batch, cancellationToken);
        await context.SaveChangesAsync(cancellationToken);

        _logger.TelemetryBatchFlushed(batch.Count);
    }
}

internal static partial class TelemetryLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Telemetry batch flushed: {Count} events")]
    public static partial void TelemetryBatchFlushed(this ILogger logger, int count);

    [LoggerMessage(Level = LogLevel.Error, Message = "Error in TelemetryBatchProcessor")]
    public static partial void TelemetryBatchError(this ILogger logger, Exception ex);
}
