namespace PondyConnect.Api.Services;

using System.Globalization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Hubs;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Smart dispatch engine. Replaces the old first-come broadcast with
/// intelligent parallel matching: offers ride to top N nearest eligible
/// drivers simultaneously, first to accept wins (distributed lock prevents
/// race conditions). Scoring: 60% distance, 20% rating, 20% acceptance rate.
/// Also sends FCM high-priority push as a fallback so drivers receive the
/// offer even when the app is backgrounded (WebSocket disconnected).
/// </summary>
public sealed class DispatchEngine
{
    private readonly IHubContext<DriverHub> _hubContext;
    private readonly IApplicationDbContext _context;
    private readonly DriverLocationStore _locationStore;
    private readonly IDistributedLock _distributedLock;
    private readonly INotificationService _notificationService;

    private static readonly TimeSpan AcceptanceWindow = TimeSpan.FromSeconds(15);
    private static readonly TimeSpan LockLease = TimeSpan.FromSeconds(30);

    public DispatchEngine(
        IHubContext<DriverHub> hubContext,
        IApplicationDbContext context,
        DriverLocationStore locationStore,
        IDistributedLock distributedLock,
        INotificationService notificationService)
    {
        _hubContext = hubContext;
        _context = context;
        _locationStore = locationStore;
        _distributedLock = distributedLock;
        _notificationService = notificationService;
    }

    /// <summary>
    /// Dispatch a ride to nearby drivers. Offers to top N nearest drivers
    /// in parallel. Returns the list of driver IDs the offer was sent to.
    /// </summary>
    public async Task<IReadOnlyList<Guid>> DispatchRideAsync(
        Guid rideId,
        double radiusKm = 3.0,
        int maxDrivers = 5,
        CancellationToken cancellationToken = default)
    {
        var ride = await _context.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == rideId, cancellationToken);
        if (ride == null) return Array.Empty<Guid>();

        // Transition to Searching
        var rideEntity = await _context.RideRequests
            .FirstOrDefaultAsync(r => r.Id == rideId, cancellationToken);
        if (rideEntity == null) return Array.Empty<Guid>();

        if (rideEntity.Status == RideStatus.Requested)
        {
            rideEntity.StartSearching();
            await _context.SaveChangesAsync(cancellationToken);
        }

        // Get nearby drivers from in-memory store
        var nearby = _locationStore.GetNearby(
            ride.PickupLocation,
            radiusKm,
            vehicleTypeFilter: ride.VehicleType,
            maxCount: maxDrivers);

        if (nearby.Count == 0)
        {
            // Try expanding radius once
            nearby = _locationStore.GetNearby(
                ride.PickupLocation,
                radiusKm: 5.0,
                vehicleTypeFilter: ride.VehicleType,
                maxCount: maxDrivers);
        }

        if (nearby.Count == 0)
        {
            rideEntity.MarkNoDriversAvailable();
            await _context.SaveChangesAsync(cancellationToken);
            return Array.Empty<Guid>();
        }

        // Score and rank drivers
        var scored = nearby
            .Select(d => new
            {
                Driver = d,
                Score = ScoreDriver(d.DistanceKm, d.Rating, d.AcceptanceRate)
            })
            .OrderByDescending(x => x.Score)
            .ToList();

        // Send targeted offers to top N drivers via SignalR
        var driverIds = scored.Select(x => x.Driver.DriverId).ToList();
        var driverEarnings = ride.IsSos ? ride.SosDriverPayout : ride.Fare;

        var offer = new RideOfferBroadcast(
            RideId: ride.Id,
            PickupAddress: ride.PickupAddress,
            DropoffAddress: ride.DropoffAddress,
            DistanceKm: ride.DistanceKm,
            Fare: ride.Fare,
            DriverEarnings: driverEarnings,
            PaymentMethod: ride.PaymentMethod.ToString(),
            VehicleType: ride.VehicleType.ToString(),
            IsSos: ride.IsSos,
            SurgeMultiplier: ride.SurgeMultiplier,
            SurgeReason: ride.SurgeReason,
            ExpiresIn: (int)AcceptanceWindow.TotalSeconds);

        foreach (var driver in scored)
        {
            // Send to specific driver connection (via group per driver)
            await _hubContext.Clients.Group($"driver:{driver.Driver.DriverId}")
                .SendAsync("RideOffer", offer, cancellationToken);

            // Also send FCM high-priority push so backgrounded drivers get the offer
            var driverUserId = await _context.Drivers.AsNoTracking()
                .Where(d => d.Id == driver.Driver.DriverId)
                .Select(d => d.UserId)
                .FirstOrDefaultAsync(cancellationToken);

            if (driverUserId != Guid.Empty)
            {
                _ = _notificationService.SendHighPriorityPushAsync(
                    driverUserId,
                    ride.IsSos ? "SOS Ride Request" : "New Ride Request",
                    $"{ride.PickupAddress} → {ride.DropoffAddress} · \u20B9{driverEarnings.ToString("0", CultureInfo.InvariantCulture)}",
                    new Dictionary<string, string>
                    {
                        { "type", "ride_request" },
                        { "ride_id", ride.Id.ToString() },
                        { "fare", ride.Fare.ToString("0", CultureInfo.InvariantCulture) },
                        { "earnings", driverEarnings.ToString("0", CultureInfo.InvariantCulture) },
                        { "pickup", ride.PickupAddress ?? "" },
                        { "dropoff", ride.DropoffAddress ?? "" },
                        { "is_sos", ride.IsSos.ToString().ToLowerInvariant() },
                        { "expires_in", ((int)AcceptanceWindow.TotalSeconds).ToString(CultureInfo.InvariantCulture) },
                    },
                    cancellationToken);
            }
        }

        return driverIds;
    }

    /// <summary>
    /// Attempt to assign a ride to a driver who accepted the offer.
    /// Uses distributed lock to prevent race conditions when multiple
    /// drivers accept simultaneously. Returns true if this driver won.
    /// </summary>
    public async Task<bool> TryAcceptOfferAsync(
        Guid rideId,
        Guid driverId,
        CancellationToken cancellationToken = default)
    {
        var lockKey = $"ride:accept:{rideId}";
        var handle = await _distributedLock.TryAcquireAsync(
            lockKey, LockLease, TimeSpan.FromMilliseconds(500), cancellationToken);

        if (handle == null)
            return false; // Another driver is already accepting

        try
        {
            await using (handle)
            {
                var ride = await _context.RideRequests
                    .FirstOrDefaultAsync(r => r.Id == rideId, cancellationToken);

                if (ride == null) return false;
                if (ride.Status is not (RideStatus.Searching or RideStatus.Requested))
                    return false; // Already assigned to another driver

                // Generate 4-digit OTP
                var otp = Random.Shared.Next(1000, 9999).ToString(System.Globalization.CultureInfo.InvariantCulture);

                ride.AssignDriver(driverId, otp);
                await _context.SaveChangesAsync(cancellationToken);

                // Update driver state
                var driver = await _context.Drivers
                    .FirstOrDefaultAsync(d => d.Id == driverId, cancellationToken);
                if (driver != null)
                {
                    driver.RecordOfferResult(true);
                    driver.StartRide(rideId);
                    await _context.SaveChangesAsync(cancellationToken);
                }

                // Update location store
                _locationStore.SetOnRide(driverId, rideId);

                return true;
            }
        }
        finally
        {
            // Lock is released by the await using
        }
    }

    /// <summary>
    /// Record that a driver declined an offer (for acceptance rate tracking).
    /// </summary>
    public async Task RecordDeclineAsync(Guid driverId, CancellationToken cancellationToken = default)
    {
        var driver = await _context.Drivers
            .FirstOrDefaultAsync(d => d.Id == driverId, cancellationToken);
        if (driver != null)
        {
            driver.RecordOfferResult(false);
            await _context.SaveChangesAsync(cancellationToken);
        }
    }

    /// <summary>
    /// Score a driver for dispatch ranking.
    /// 60% proximity (closer = better), 20% rating, 20% acceptance rate.
    /// </summary>
    private static double ScoreDriver(double distanceKm, double rating, double acceptanceRate)
    {
        var proximityScore = 1.0 / (1.0 + distanceKm); // 0-1, closer to 1 for near
        var ratingScore = rating / 5.0; // 0-1
        var acceptanceScore = acceptanceRate; // 0-1

        return (0.6 * proximityScore) + (0.2 * ratingScore) + (0.2 * acceptanceScore);
    }
}

/// <summary>
/// SignalR broadcast payload for a ride offer sent to specific drivers.
/// </summary>
public sealed record RideOfferBroadcast(
    Guid RideId,
    string PickupAddress,
    string DropoffAddress,
    double DistanceKm,
    decimal Fare,
    decimal DriverEarnings,
    string PaymentMethod,
    string VehicleType,
    bool IsSos,
    decimal SurgeMultiplier,
    string? SurgeReason,
    int ExpiresIn);
