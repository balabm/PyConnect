namespace PondyConnect.Api.Services;

using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background service that monitors kitchen overload and auto-throttles
/// estimated delivery times. Runs every 2 minutes.
///
/// If a vendor has 5+ orders in the Preparing state for more than 20
/// minutes, the worker:
/// 1. Sets Vendor.DynamicPrepBufferMinutes = 15 (adds 15 min to all ETAs)
/// 2. Broadcasts a VendorUpdated SignalR event to all active Consumer
///    clients within 5km so they see the updated delivery times.
///
/// When the backlog clears (fewer than 5 stuck orders), the buffer is
/// reset to 0.
/// </summary>
public sealed class KdsThrottlingWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly IHubContext<VendorHub> _vendorHub;
    private readonly ILogger<KdsThrottlingWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromMinutes(2);
    private const int StuckOrderThreshold = 5;
    private static readonly TimeSpan StuckOrderAge = TimeSpan.FromMinutes(20);
    private const int ThrottleBufferMinutes = 15;

    public KdsThrottlingWorker(
        IServiceProvider services,
        IHubContext<VendorHub> vendorHub,
        ILogger<KdsThrottlingWorker> logger)
    {
        _services = services;
        _vendorHub = vendorHub;
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

                var cutoff = DateTimeOffset.UtcNow - StuckOrderAge;

                // Find vendors with 5+ stuck Preparing orders
                var stuckVendors = await context.FoodOrders
                    .Where(o => o.Status == FoodOrderStatus.Preparing && o.PlacedAt < cutoff)
                    .GroupBy(o => o.VendorId)
                    .Where(g => g.Count() >= StuckOrderThreshold)
                    .Select(g => g.Key)
                    .ToListAsync(stoppingToken);

                foreach (var vendorId in stuckVendors)
                {
                    var vendor = await context.Vendors.FirstOrDefaultAsync(v => v.Id == vendorId, stoppingToken);
                    if (vendor is null || vendor.DynamicPrepBufferMinutes >= ThrottleBufferMinutes)
                        continue; // Already throttled

                    vendor.SetDynamicPrepBuffer(ThrottleBufferMinutes);
                    await context.SaveChangesAsync(stoppingToken);

                    // Broadcast to all clients watching this vendor
                    await _vendorHub.Clients.Group($"vendor:{vendorId}")
                        .SendAsync("VendorThrottled", new
                        {
                            VendorId = vendorId,
                            PrepBufferMinutes = ThrottleBufferMinutes,
                            Message = "Kitchen overload detected. Estimated delivery times adjusted."
                        }, stoppingToken);

                    _logger.KitchenThrottled(vendorId, ThrottleBufferMinutes);
                }

                // Reset buffer for vendors whose backlog has cleared
                var allFoodVendors = await context.Vendors
                    .Where(v => v.DynamicPrepBufferMinutes > 0 && !v.IsBusyMode)
                    .Select(v => new { v.Id, v.DynamicPrepBufferMinutes })
                    .ToListAsync(stoppingToken);

                foreach (var v in allFoodVendors)
                {
                    var stuckCount = await context.FoodOrders
                        .Where(o => o.VendorId == v.Id && o.Status == FoodOrderStatus.Preparing && o.PlacedAt < cutoff)
                        .CountAsync(stoppingToken);

                    if (stuckCount < StuckOrderThreshold)
                    {
                        var vendor = await context.Vendors.FirstOrDefaultAsync(x => x.Id == v.Id, stoppingToken);
                        if (vendor is not null)
                        {
                            vendor.SetDynamicPrepBuffer(0);
                            await context.SaveChangesAsync(stoppingToken);

                            await _vendorHub.Clients.Group($"vendor:{v.Id}")
                                .SendAsync("VendorThrottled", new
                                {
                                    VendorId = v.Id,
                                    PrepBufferMinutes = 0,
                                    Message = "Kitchen backlog cleared. Normal delivery times restored."
                                }, stoppingToken);

                            _logger.KitchenThrottleCleared(v.Id);
                        }
                    }
                }
            }
            catch (OperationCanceledException)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error during KDS throttling check");
            }
        }
    }
}

internal static partial class KdsThrottlingLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Warning, Message = "Kitchen overload: Vendor {VendorId} throttled with +{Buffer}min prep buffer")]
    public static partial void KitchenThrottled(this ILogger logger, Guid vendorId, int buffer);

    [LoggerMessage(Level = LogLevel.Information, Message = "Kitchen backlog cleared: Vendor {VendorId} prep buffer reset to 0")]
    public static partial void KitchenThrottleCleared(this ILogger logger, Guid vendorId);
}
