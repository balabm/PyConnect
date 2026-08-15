namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

public sealed class ScheduledPayoutWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<ScheduledPayoutWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromHours(1);

    public ScheduledPayoutWorker(IServiceProvider serviceProvider, ILogger<ScheduledPayoutWorker> logger)
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
                var istNow = DateTimeOffset.UtcNow.AddMinutes(330); // UTC+5:30
                var isPayoutDay = istNow.DayOfWeek == DayOfWeek.Tuesday || istNow.DayOfWeek == DayOfWeek.Friday;
                var isPayoutWindow = istNow.Hour == 9 && istNow.Minute < 30;

                if (isPayoutDay && isPayoutWindow)
                {
                    using var scope = _serviceProvider.CreateScope();
                    var payoutService = scope.ServiceProvider.GetRequiredService<DriverPayoutService>();

                    var count = await payoutService.ProcessScheduledPayouts(stoppingToken);
                    _logger.ScheduledPayoutsProcessed(count);

                    await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.ScheduledPayoutWorkerError(ex);
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }
}

internal static partial class ScheduledPayoutLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Scheduled payouts processed: {Count} drivers paid out")]
    public static partial void ScheduledPayoutsProcessed(this ILogger logger, int count);

    [LoggerMessage(Level = LogLevel.Error, Message = "Error in ScheduledPayoutWorker")]
    public static partial void ScheduledPayoutWorkerError(this ILogger logger, Exception ex);
}
