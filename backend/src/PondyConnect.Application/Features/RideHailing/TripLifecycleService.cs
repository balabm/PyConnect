namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// Handles mid-trip edge cases: vehicle breakdown splits, rider no-show
/// cancellation fees, route deviation fare locks, and toll/parking
/// pass-through surcharges.
/// </summary>
public sealed class TripLifecycleService
{
    private readonly IApplicationDbContext _context;
    private readonly WalletService _wallet;
    private readonly RidePricingService _pricingService;
    private readonly ILogger<TripLifecycleService> _logger;

    public TripLifecycleService(
        IApplicationDbContext context,
        WalletService wallet,
        RidePricingService pricingService,
        ILogger<TripLifecycleService> logger)
    {
        _context = context;
        _wallet = wallet;
        _pricingService = pricingService;
        _logger = logger;
    }

    /// <summary>
    /// Handles a mid-trip vehicle breakdown. Splits the ride into two legs:
    /// - Leg 1: pickup → breakdown location (rider pays prorated fare)
    /// - Leg 2: breakdown location → original dropoff (new dispatch, priority)
    ///
    /// The original ride is completed with the traveled distance. A new
    /// RideRequest is created for the remaining distance and dispatched
    /// to nearby drivers with high priority.
    /// </summary>
    public async Task<BreakdownSplitResult> HandleBreakdownAsync(
        Guid rideId,
        Guid driverId,
        double breakdownLat,
        double breakdownLng,
        CancellationToken ct = default)
    {
        var ride = await _context.RideRequests
            .FirstOrDefaultAsync(r => r.Id == rideId, ct)
            ?? throw new InvalidOperationException("Ride not found.");

        if (ride.DriverId != driverId)
            throw new UnauthorizedAccessException("Only the assigned driver can declare a breakdown.");

        if (ride.Status != RideStatus.EnRoute)
            throw new InvalidOperationException("Breakdown can only be declared during an active ride.");

        var breakdownLocation = new GeoLocation(breakdownLat, breakdownLng);

        // Calculate traveled distance using Haversine
        var traveledDistance = ride.PickupLocation.DistanceKm(breakdownLocation);
        var traveledDuration = ride.StartedAt is { } started
            ? (int)(DateTimeOffset.UtcNow - started).TotalMinutes
            : 0;

        // Calculate remaining distance
        var remainingDistance = breakdownLocation.DistanceKm(ride.DropoffLocation);
        var remainingDuration = _pricingService.EstimateDurationMin(remainingDistance, ride.VehicleType);

        // Complete Leg 1 with prorated fare
        ride.CompleteWithBreakdown(traveledDistance, traveledDuration);
        var leg1Fare = _pricingService.CalculateFareWithSurge(
            traveledDistance,
            traveledDuration,
            ride.VehicleType,
            ride.SurgeMultiplier,
            ride.SurgeReason);

        // Update the original ride's fare to the prorated amount
        ride.GetType().GetProperty("Fare")?.SetValue(ride, leg1Fare.Fare);
        ride.GetType().GetProperty("TotalAmount")?.SetValue(ride, leg1Fare.TotalAmount);

        // Create Leg 2 ride for the remaining distance
        var leg2Fare = _pricingService.CalculateFareWithSurge(
            remainingDistance,
            remainingDuration,
            ride.VehicleType,
            ride.SurgeMultiplier,
            ride.SurgeReason);

        var splitRide = RideRequest.CreateSplitRide(
            originalRideId: rideId,
            userId: ride.UserId,
            breakdownLocation: breakdownLocation,
            breakdownAddress: $"Breakdown location ({breakdownLat:F4}, {breakdownLng:F4})",
            originalDropoff: ride.DropoffLocation,
            originalDropoffAddress: ride.DropoffAddress,
            remainingDistanceKm: remainingDistance,
            remainingDurationMin: remainingDuration,
            vehicleType: ride.VehicleType,
            fare: leg2Fare.Fare,
            paymentMethod: ride.PaymentMethod,
            surgeMultiplier: ride.SurgeMultiplier,
            surgeReason: ride.SurgeReason,
            baseFare: leg2Fare.BaseFare,
            distanceFare: leg2Fare.DistanceFare,
            timeFare: leg2Fare.TimeFare);

        splitRide.StartSearching();
        _context.RideRequests.Add(splitRide);
        await _context.SaveChangesAsync(ct);

        _logger.BreakdownSplit(rideId, splitRide.Id, driverId, traveledDistance, remainingDistance);

        return new BreakdownSplitResult(
            OriginalRideId: rideId,
            SplitRideId: splitRide.Id,
            Leg1Fare: leg1Fare.TotalAmount,
            Leg2Fare: leg2Fare.TotalAmount,
            TraveledDistanceKm: traveledDistance,
            RemainingDistanceKm: remainingDistance);
    }

    /// <summary>
    /// Declares a rider no-show at pickup. The captain must have arrived
    /// and waited at least 5 minutes. The rider is charged a ₹50
    /// cancellation fee credited to the captain's wallet.
    /// </summary>
    public async Task<decimal> HandleRiderNoShowAsync(
        Guid rideId,
        Guid driverId,
        CancellationToken ct = default)
    {
        var ride = await _context.RideRequests
            .FirstOrDefaultAsync(r => r.Id == rideId, ct)
            ?? throw new InvalidOperationException("Ride not found.");

        if (ride.DriverId != driverId)
            throw new UnauthorizedAccessException("Only the assigned driver can declare a no-show.");

        ride.CancelForRiderNoShow();

        // Credit the cancellation fee to the driver's wallet
        if (ride.CancellationFee > 0)
        {
            await _wallet.RecordCommissionAsync(
                driverId,
                -ride.CancellationFee, // Negative commission = credit to driver
                rideId.ToString(),
                "Rider no-show cancellation fee",
                ct);
        }

        await _context.SaveChangesAsync(ct);

        _logger.RiderNoShow(rideId, driverId, ride.CancellationFee);
        return ride.CancellationFee;
    }

    /// <summary>
    /// Locks the fare due to route deviation. Prevents inflated metered
    /// charges during safety review. Sends an alert to the admin SOS hub.
    /// </summary>
    public async Task LockFareForDeviationAsync(
        Guid rideId,
        CancellationToken ct = default)
    {
        var ride = await _context.RideRequests
            .FirstOrDefaultAsync(r => r.Id == rideId, ct)
            ?? throw new InvalidOperationException("Ride not found.");

        ride.LockFare();
        await _context.SaveChangesAsync(ct);

        _logger.FareLocked(rideId);
    }

    /// <summary>
    /// Adds a toll/parking pass-through surcharge to the ride. The captain
    /// enters the receipt amount before ending the trip. Zero platform
    /// deduction — 100% goes to the driver.
    /// </summary>
    public async Task AddTollAndParkingAsync(
        Guid rideId,
        Guid driverId,
        decimal amount,
        string? receiptUrl = null,
        CancellationToken ct = default)
    {
        var ride = await _context.RideRequests
            .FirstOrDefaultAsync(r => r.Id == rideId, ct)
            ?? throw new InvalidOperationException("Ride not found.");

        if (ride.DriverId != driverId)
            throw new UnauthorizedAccessException("Only the assigned driver can add toll/parking.");

        ride.AddTollAndParking(amount, receiptUrl);
        await _context.SaveChangesAsync(ct);

        _logger.TollAdded(rideId, amount);
    }
}

public sealed record BreakdownSplitResult(
    Guid OriginalRideId,
    Guid SplitRideId,
    decimal Leg1Fare,
    decimal Leg2Fare,
    double TraveledDistanceKm,
    double RemainingDistanceKm);

internal static partial class TripLifecycleLoggerExtensions
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Breakdown split: Ride {RideId} → {SplitRideId} by driver {DriverId}. Leg1: {TraveledKm:F1}km, Leg2: {RemainingKm:F1}km")]
    public static partial void BreakdownSplit(this ILogger logger, Guid rideId, Guid splitRideId, Guid driverId, double traveledKm, double remainingKm);

    [LoggerMessage(Level = LogLevel.Information, Message = "Rider no-show on ride {RideId} by driver {DriverId}. Fee: ₹{Fee}")]
    public static partial void RiderNoShow(this ILogger logger, Guid rideId, Guid driverId, decimal fee);

    [LoggerMessage(Level = LogLevel.Warning, Message = "Fare locked for ride {RideId} due to route deviation")]
    public static partial void FareLocked(this ILogger logger, Guid rideId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Toll/parking ₹{Amount} added to ride {RideId}")]
    public static partial void TollAdded(this ILogger logger, Guid rideId, decimal amount);
}
