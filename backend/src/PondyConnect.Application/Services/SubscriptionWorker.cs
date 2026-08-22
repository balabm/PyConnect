namespace PondyConnect.Application.Services;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Features.Subscriptions;

/// <summary>
/// Daily background worker that:
/// 1. Revokes PY Prime for users whose grace period has expired.
/// 2. Sends renewal reminders 3 days before expiry.
/// Runs at 09:00 IST (03:30 UTC) every day.
/// </summary>
public sealed class SubscriptionWorker : BackgroundService
{
    private readonly IServiceProvider _services;
    private readonly ILogger<SubscriptionWorker> _logger;
    private static readonly TimeSpan Interval = TimeSpan.FromHours(6);

    public SubscriptionWorker(
        IServiceProvider services,
        ILogger<SubscriptionWorker> logger)
    {
        _services = services;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        _logger.LogInformation("SubscriptionWorker started");

        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _services.CreateScope();
                var subscriptionService = scope.ServiceProvider
                    .GetRequiredService<SubscriptionService>();

                var revoked = await subscriptionService.RevokeExpiredSubscriptionsAsync(stoppingToken);

                if (revoked > 0)
                {
                    _logger.LogInformation(
                        "SubscriptionWorker: revoked Prime for {Count} users",
                        revoked);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "SubscriptionWorker error");
            }

            await Task.Delay(Interval, stoppingToken);
        }
    }
}
