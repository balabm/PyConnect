namespace PondyConnect.Api.Services;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Settlement;

/// <summary>
/// Daily settlement worker that runs at midnight IST (18:30 UTC) to
/// process vendor and driver payouts. Groups pending settlements,
/// calls the payout service, and records double-entry ledger entries.
/// </summary>
public sealed class SettlementWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<SettlementWorker> _logger;
    private static readonly TimeSpan CheckInterval = TimeSpan.FromHours(1);

    // IST midnight = 18:30 UTC
    private static readonly TimeSpan SettlementTimeUtc = new(18, 30, 0);
    private DateOnly? _lastRunDate;

    public SettlementWorker(IServiceProvider services, ILogger<SettlementWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(CheckInterval, stoppingToken);

                var nowUtc = DateTimeOffset.UtcNow;
                var today = DateOnly.FromDateTime(nowUtc.Date);

                // Run at or after IST midnight (18:30 UTC), once per day
                if (nowUtc.TimeOfDay >= SettlementTimeUtc && _lastRunDate != today)
                {
                    _lastRunDate = today;

                    using var scope = _services.CreateScope();
                    var settlementService = scope.ServiceProvider.GetRequiredService<SettlementService>();

                    _logger.LogInformation("Starting daily settlement at {Time}", nowUtc);

                    var vendorPayouts = await settlementService.ProcessVendorPayoutsAsync(stoppingToken);
                    var driverPayouts = await settlementService.ProcessDriverPayoutsAsync(stoppingToken);

                    _logger.LogInformation("Daily settlement complete: {VendorCount} vendor payouts, {DriverCount} driver payouts",
                        vendorPayouts, driverPayouts);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during daily settlement");
            }
        }
    }
}
