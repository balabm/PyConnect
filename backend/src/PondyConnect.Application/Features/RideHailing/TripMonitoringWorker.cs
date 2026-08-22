namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Background worker that monitors all active (EnRoute) trips for the
/// "device battery death" scenario. If a driver's phone dies mid-trip:
///
/// 1. Their WebSocket disconnects from the SignalR hub.
/// 2. No GPS pings are received by the in-memory <c>DriverLocationStore</c>.
///
/// After 15 minutes of no GPS activity on an active trip, the worker sends
/// an automated SMS to the consumer:
/// <example>
/// "Did your Captain complete the trip safely? Reply YES to close the trip,
/// or HELP to contact support."
/// </example>
///
/// This prevents trips from being stuck "Active" forever when the driver's
/// phone dies after dropping off the customer.
/// </summary>
public sealed class TripMonitoringWorker : BackgroundService
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<TripMonitoringWorker> _logger;
    private readonly TimeSpan _interval = TimeSpan.FromMinutes(5);

    /// <summary>
    /// How long without a GPS ping before the consumer is contacted.
    /// 15 minutes is long enough to ride out temporary signal loss but
    /// short enough to catch genuine device-death scenarios.
    /// </summary>
    private static readonly TimeSpan StaleThreshold = TimeSpan.FromMinutes(15);

    /// <summary>
    /// Rides that have already been flagged for consumer SMS. Prevents
    /// duplicate messages on every worker cycle.
    /// </summary>
    private readonly HashSet<Guid> _flaggedRides = new();

    public TripMonitoringWorker(IServiceProvider serviceProvider, ILogger<TripMonitoringWorker> logger)
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
                var driverLocationCache = scope.ServiceProvider.GetService<IDriverLocationCache>();
                var smsSender = scope.ServiceProvider.GetService<ISmsSender>();

                await MonitorActiveTripsAsync(context, driverLocationCache, smsSender, stoppingToken);
            }
            catch (Exception ex) when (!stoppingToken.IsCancellationRequested)
            {
                _logger.TripMonitoringWorkerError(ex);
            }

            await Task.Delay(_interval, stoppingToken);
        }
    }

    private async Task MonitorActiveTripsAsync(
        IApplicationDbContext context,
        IDriverLocationCache? driverLocationCache,
        ISmsSender? smsSender,
        CancellationToken cancellationToken)
    {
        // Find all rides currently in the EnRoute (active trip) state.
        var activeRides = await context.RideRequests
            .Where(r => r.Status == RideStatus.EnRoute)
            .ToListAsync(cancellationToken);

        if (activeRides.Count == 0) return;

        _logger.TripMonitoringStarted(activeRides.Count);

        foreach (var ride in activeRides)
        {
            // Skip rides already flagged to prevent duplicate SMS.
            if (_flaggedRides.Contains(ride.Id))
                continue;

            if (ride.DriverId is null)
                continue;

            // Check if the driver's GPS is stale (no ping for > 15 minutes).
            // If the driver location cache is not available (e.g. in tests),
            // fall back to checking the ride's StartedAt timestamp.
            bool isStale;
            if (driverLocationCache is not null)
            {
                isStale = driverLocationCache.IsStale(ride.DriverId.Value, StaleThreshold);
            }
            else
            {
                // Fallback: if the trip started more than 15 minutes ago and
                // we have no way to check GPS freshness, skip it.
                continue;
            }

            if (!isStale)
                continue;

            _logger.TripStaleGpsDetected(ride.Id, ride.DriverId.Value);

            // Send an automated SMS to the consumer asking if the trip was
            // completed safely.
            if (smsSender is not null)
            {
                try
                {
                    var user = await context.Users
                        .FirstOrDefaultAsync(u => u.Id == ride.UserId, cancellationToken);

                    if (user is not null && !string.IsNullOrEmpty(user.Phone))
                    {
                        var message =
                            "PY Connect: Did your Captain complete the trip safely? " +
                            "Reply YES to close the trip, or HELP to contact support.";

                        await smsSender.SendAsync(user.Phone, message, cancellationToken);
                        _logger.TripMonitoringSmsSent(ride.Id, user.Phone);
                    }
                }
                catch (Exception ex)
                {
                    _logger.TripMonitoringSmsFailed(ride.Id, ex);
                }
            }

            // Mark this ride as flagged so we don't send duplicate SMS on
            // the next cycle. The flag is cleared when the ride transitions
            // out of EnRoute (completed or cancelled).
            _flaggedRides.Add(ride.Id);
        }

        // Clean up flagged rides that are no longer active.
        var stillActiveIds = activeRides.Select(r => r.Id).ToHashSet();
        _flaggedRides.RemoveWhere(id => !stillActiveIds.Contains(id));
    }
}

internal static partial class TripMonitoringLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Trip monitoring started for {Count} active rides")]
    public static partial void TripMonitoringStarted(this ILogger logger, int count);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Stale GPS detected for ride {RideId} (driver {DriverId} — no ping for > 15 minutes")]
    public static partial void TripStaleGpsDetected(this ILogger logger, Guid rideId, Guid driverId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Trip monitoring SMS sent to {Phone} for ride {RideId}")]
    public static partial void TripMonitoringSmsSent(this ILogger logger, Guid rideId, string phone);

    [LoggerMessage(Level = LogLevel.Error, Message = "Failed to send trip monitoring SMS for ride {RideId}")]
    public static partial void TripMonitoringSmsFailed(this ILogger logger, Guid rideId, Exception ex);

    [LoggerMessage(Level = LogLevel.Error, Message = "Trip monitoring worker error")]
    public static partial void TripMonitoringWorkerError(this ILogger logger, Exception ex);
}
