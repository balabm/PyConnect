namespace PondyConnect.Api.Services;

using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Homestays;

/// <summary>
/// Background service that periodically releases expired pending
/// inventory locks. Runs every 2 minutes. When a user selects dates
/// but doesn't pay within 10 minutes, the lock expires and the dates
/// are returned to the public pool.
/// </summary>
public sealed class InventoryLockCleanupService : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<InventoryLockCleanupService> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(2);

    public InventoryLockCleanupService(IServiceProvider services, ILogger<InventoryLockCleanupService> logger)
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
                await Task.Delay(Interval, stoppingToken);

                using var scope = _services.CreateScope();
                var inventory = scope.ServiceProvider.GetRequiredService<InventoryService>();

                var released = await inventory.ReleaseExpiredLocksAsync(stoppingToken);
                if (released > 0)
                {
                    _logger.LogInformation("Inventory lock cleanup: released {Count} expired locks", released);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during inventory lock cleanup");
            }
        }
    }
}
