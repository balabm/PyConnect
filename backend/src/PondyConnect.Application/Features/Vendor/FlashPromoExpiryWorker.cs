namespace PondyConnect.Application.Features.Vendor;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed class FlashPromoExpiryWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<FlashPromoExpiryWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromSeconds(30);

    public FlashPromoExpiryWorker(IServiceProvider serviceProvider, ILogger<FlashPromoExpiryWorker> logger)
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
                var now = DateTimeOffset.UtcNow;

                var expiredPromos = (await context.VendorPromotions
                    .Where(p => p.PromoType == PromoType.FlashSale && p.IsActive)
                    .ToListAsync(stoppingToken))
                    .Where(p => p.ExpiresAt <= now)
                    .ToList();

                foreach (var promo in expiredPromos)
                {
                    promo.Deactivate();
                    _logger.FlashPromoExpired(promo.Id);
                }

                if (expiredPromos.Count > 0)
                    await context.SaveChangesAsync(stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.FlashPromoWorkerError(ex);
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }
}

internal static partial class FlashPromoLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Flash promo {PromoId} expired and deactivated")]
    public static partial void FlashPromoExpired(this ILogger logger, Guid promoId);

    [LoggerMessage(Level = LogLevel.Error, Message = "Error in FlashPromoExpiryWorker")]
    public static partial void FlashPromoWorkerError(this ILogger logger, Exception ex);
}
