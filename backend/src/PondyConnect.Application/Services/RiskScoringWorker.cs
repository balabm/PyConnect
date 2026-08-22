namespace PondyConnect.Application.Services;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background sentinel that scans for users with abnormal patterns
/// (e.g., 3+ refund requests in a week) and adjusts their trust score.
/// Runs every 2 hours.
/// </summary>
public sealed class RiskScoringWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<RiskScoringWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(2);

    /// <summary>
    /// Rolling window for detecting refund abuse (7 days).
    /// </summary>
    private static readonly TimeSpan RefundAbuseWindow = TimeSpan.FromDays(7);

    /// <summary>
    /// Number of refunds in the window that triggers a trust score penalty.
    /// </summary>
    private const int RefundAbuseThreshold = 3;

    public RiskScoringWorker(
        IServiceProvider services,
        ILogger<RiskScoringWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("RiskScoringWorker started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _services.CreateScope();
                var context = scope.ServiceProvider.GetRequiredService<IApplicationDbContext>();
                var riskService = scope.ServiceProvider
                    .GetRequiredService<RiskScoringService>();

                await ScanRefundAbuseAsync(context, riskService, stoppingToken);
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "RiskScoringWorker error");
            }

            await Task.Delay(Interval, stoppingToken);
        }
    }

    private static async Task ScanRefundAbuseAsync(
        IApplicationDbContext context,
        RiskScoringService riskService,
        CancellationToken ct)
    {
        var cutoff = DateTimeOffset.UtcNow - RefundAbuseWindow;

        // Find users with 3+ refunded food orders in the last 7 days
        var refundAbusers = await context.FoodOrders
            .AsNoTracking()
            .Where(o => o.PaymentStatus == PaymentStatus.Refunded
                && o.PlacedAt >= cutoff)
            .GroupBy(o => o.UserId)
            .Where(g => g.Count() >= RefundAbuseThreshold)
            .Select(g => g.Key)
            .ToListAsync(ct);

        foreach (var userId in refundAbusers)
        {
            // Apply -10 for each refund beyond the threshold (max -30 per scan)
            // The RiskScoringService handles clamping and flag updates
            await riskService.RecordFoodRefundAsync(userId, ct);
        }
    }
}
