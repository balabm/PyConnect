namespace PondyConnect.Application.Features.RideHailing;

using PondyConnect.Domain.Enums;

/// <summary>
/// Transparent ride pricing: 100% of fare goes to driver.
/// Formula: Total = (BaseFare + DistanceFare + TimeFare) × SurgeMultiplier + PlatformBookingFee
/// PlatformBookingFee = flat ₹15 charged to rider on top of fare.
/// Surge is capped at 1.5x and driver receives 100% of the surge portion.
/// </summary>
public static class RidePricingService
{
    public const decimal PlatformBookingFee = 15m;
    public const decimal MaxSurgeMultiplier = 1.5m;

    // Per vehicle type rates
    private const decimal BikeBaseFare = 15m;
    private const decimal BikeRatePerKm = 8m;
    private const decimal BikeRatePerMin = 1m;
    private const decimal BikeMinFare = 30m;

    private const decimal AutoBaseFare = 25m;
    private const decimal AutoRatePerKm = 12m;
    private const decimal AutoRatePerMin = 1.5m;
    private const decimal AutoMinFare = 50m;

    private const decimal CarBaseFare = 40m;
    private const decimal CarRatePerKm = 15m;
    private const decimal CarRatePerMin = 2m;
    private const decimal CarMinFare = 70m;

    public static RidePricing CalculateFare(double distanceKm, VehicleType vehicleType)
        => CalculateFareWithSurge(distanceKm, EstimateDurationMin(distanceKm, vehicleType), vehicleType, 1.0m, null);

    public static RidePricing CalculateFareWithSurge(
        double distanceKm,
        int estimatedDurationMin,
        VehicleType vehicleType,
        decimal surgeMultiplier = 1.0m,
        string? surgeReason = null)
    {
        var (baseFare, ratePerKm, ratePerMin, minFare) = GetRates(vehicleType);

        // Cap surge at 1.5x
        var surge = Math.Min(surgeMultiplier, MaxSurgeMultiplier);

        var distanceFare = Math.Ceiling((decimal)distanceKm * ratePerKm);
        var timeFare = Math.Ceiling((decimal)estimatedDurationMin * ratePerMin);
        var subtotal = baseFare + distanceFare + timeFare;

        // Apply surge to the ride portion (base + distance + time), not the platform fee
        var surgedSubtotal = Math.Ceiling(subtotal * surge);

        // Enforce minimum fare
        var fare = Math.Max(surgedSubtotal, minFare);
        var total = fare + PlatformBookingFee;

        return new RidePricing(
            Fare: fare,
            PlatformBookingFee: PlatformBookingFee,
            TotalAmount: total,
            DriverEarnings: fare,
            BaseFare: baseFare,
            DistanceFare: distanceFare,
            TimeFare: timeFare,
            SurgeMultiplier: surge,
            SurgeReason: surgeReason);
    }

    public static int EstimateDurationMin(double distanceKm, VehicleType vehicleType)
    {
        var avgSpeedKmh = vehicleType switch
        {
            VehicleType.Bike => 25,
            VehicleType.Auto => 18,
            VehicleType.Car => 22,
            _ => 25
        };
        return (int)Math.Ceiling(distanceKm / avgSpeedKmh * 60);
    }

    public static SosPricing CalculateSosFare(decimal baseDistanceFare)
    {
        var grossSosFare = baseDistanceFare * 2.5m;
        var driverPayout = baseDistanceFare * 2.2m;
        var platformEmergencyFee = baseDistanceFare * 0.3m;

        return new SosPricing(
            GrossSosFare: grossSosFare,
            DriverPayout: driverPayout,
            PlatformEmergencyFee: platformEmergencyFee,
            TotalAmount: grossSosFare);
    }

    private static (decimal BaseFare, decimal RatePerKm, decimal RatePerMin, decimal MinFare) GetRates(VehicleType vehicleType) =>
        vehicleType switch
        {
            VehicleType.Bike => (BikeBaseFare, BikeRatePerKm, BikeRatePerMin, BikeMinFare),
            VehicleType.Auto => (AutoBaseFare, AutoRatePerKm, AutoRatePerMin, AutoMinFare),
            VehicleType.Car => (CarBaseFare, CarRatePerKm, CarRatePerMin, CarMinFare),
            _ => (BikeBaseFare, BikeRatePerKm, BikeRatePerMin, BikeMinFare)
        };
}

public sealed record RidePricing(
    decimal Fare,
    decimal PlatformBookingFee,
    decimal TotalAmount,
    decimal DriverEarnings,
    decimal BaseFare = 0m,
    decimal DistanceFare = 0m,
    decimal TimeFare = 0m,
    decimal SurgeMultiplier = 1.0m,
    string? SurgeReason = null);

public sealed record SosPricing(
    decimal GrossSosFare,
    decimal DriverPayout,
    decimal PlatformEmergencyFee,
    decimal TotalAmount);
