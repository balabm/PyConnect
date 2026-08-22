namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Wallet;

/// <summary>
/// Background worker that monitors all driver wallets for debt threshold
/// violations. If a driver's wallet balance hits the hard limit (₹-1000),
/// the worker:
/// 1. Suspends the driver (sets Suspended = true on the wallet).
/// 2. Sets the driver offline.
/// 3. Sends a targeted SignalR payload that forces the Captain's Flutter
///    app to instantly toggle Offline.
///
/// Runs every 30 seconds to catch debt violations in near real-time.
/// </summary>
public sealed class WalletMonitorWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly IHubContext<DriverHub> _driverHub;
    private readonly ILogger<WalletMonitorWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

    public WalletMonitorWorker(
        IServiceProvider services,
        IHubContext<DriverHub> driverHub,
        ILogger<WalletMonitorWorker> logger)
    {
        _services = services;
        _driverHub = driverHub;
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
                var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                var walletService = scope.ServiceProvider.GetRequiredService<WalletService>();

                // Find all drivers with wallets that are at or below the hard limit
                // and not yet suspended.
                var atRiskWallets = await context.DriverWallets
                    .Where(w => w.Balance <= w.HardLimit && !w.Suspended)
                    .ToListAsync(stoppingToken);

                foreach (var wallet in atRiskWallets)
                {
                    // Suspend the wallet
                    wallet.SuspendIfAtHardLimit();

                    // Set the driver offline
                    var driver = await context.Drivers
                        .FirstOrDefaultAsync(d => d.Id == wallet.DriverId, stoppingToken);

                    if (driver is not null && driver.IsOnline)
                    {
                        driver.GoOffline();

                        // Send SignalR kick — forces the Captain's app to toggle Offline
                        await _driverHub.Clients.Group($"driver:{driver.Id}")
                            .SendAsync("ForceOffline", new
                            {
                                Reason = "Account Paused. Please clear your outstanding dues to continue receiving orders.",
                                OutstandingAmount = Math.Abs(wallet.Balance),
                                Timestamp = DateTimeOffset.UtcNow
                            }, stoppingToken);

                        _logger.LogWarning("Driver {DriverId} suspended due to debt. Balance: {Balance}", driver.Id, wallet.Balance);
                    }
                }

                if (atRiskWallets.Count > 0)
                {
                    await context.SaveChangesAsync(stoppingToken);
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during wallet monitoring");
            }
        }
    }
}
