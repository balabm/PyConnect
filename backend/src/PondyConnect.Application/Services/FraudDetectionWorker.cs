namespace PondyConnect.Application.Services;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background worker that runs every hour to scan for consumers with high
/// post-assignment cancellation rates. Consumers that meet the threshold are
/// automatically shadow-banned and COD-restricted via
/// <see cref="IFraudDetectionService.EvaluateConsumerAsync"/>.
/// </summary>
public sealed class FraudDetectionWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<FraudDetectionWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromHours(1);

    public FraudDetectionWorker(IServiceProvider serviceProvider, ILogger<FraudDetectionWorker> logger)
    {
        _serviceProvider = serviceProvider;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _serviceProvider.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                var fraudService = scope.ServiceProvider.GetRequiredService<IFraudDetectionService>();

                var cutoff = DateTimeOffset.UtcNow - FraudDetectionService.CancellationWindow;

                // Find distinct consumers who have cancelled rides after driver
                // assignment within the rolling 24-hour window.
                var flaggedConsumers = await context.RideRequests
                    .AsNoTracking()
                    .Where(r => r.Status == RideStatus.Cancelled
                        && r.DriverId.HasValue
                        && r.CancelledAt.HasValue
                        && r.CancelledAt.Value >= cutoff)
                    .Select(r => r.UserId.ToString())
                    .Distinct()
                    .ToListAsync(stoppingToken);

                foreach (var consumerId in flaggedConsumers)
                {
                    // EvaluateConsumerAsync checks the count and applies
                    // shadow-ban / COD restriction if the threshold is met.
                    await fraudService.EvaluateConsumerAsync(consumerId);
                    _logger.LogInformation("Fraud detection evaluated consumer {ConsumerId}.", consumerId);
                }

                if (flaggedConsumers.Count > 0)
                {
                    _logger.LogInformation(
                        "Fraud detection scan complete: {Count} consumers evaluated.",
                        flaggedConsumers.Count);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error in FraudDetectionWorker scan.");
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }
}
