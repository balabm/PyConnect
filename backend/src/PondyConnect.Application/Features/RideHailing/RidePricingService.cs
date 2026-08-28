namespace PondyConnect.Application.Features.RideHailing;

using Microsoft.Extensions.Options;
using PondyConnect.Domain.Enums;

/// <summary>
/// Transparent ride pricing: 100% of fare goes to driver.
/// Formula: Total = (BaseFare + DistanceFare + TimeFare) × SurgeMultiplier + PlatformBookingFee
/// PlatformBookingFee is charged to rider on top of fare.
/// Surge is capped and driver receives 100% of the surge portion.
/// All rates are configurable via <see cref="RidePricingOptions"/>.
/// </summary>
public sealed class RidePricingService
{
    private readonly RidePricingOptions _options;

    public RidePricingService(IOptions<RidePricingOptions> options)
    {
        _options = options.Value;
    }

    public RidePricing CalculateFare(double distanceKm, VehicleType vehicleType)
        => CalculateFareWithSurge(distanceKm, EstimateDurationMin(distanceKm, vehicleType), vehicleType, 1.0m, null);

    public RidePricing CalculateFareWithSurge(
        double distanceKm,
        int estimatedDurationMin,
        VehicleType vehicleType,
        decimal surgeMultiplier = 1.0m,
        string? surgeReason = null)
    {
        var rate = _options.GetRate(vehicleType);

        // Cap surge at the configured maximum
        var surge = Math.Min(surgeMultiplier, _options.MaxSurgeMultiplier);

        var distanceFare = Math.Ceiling((decimal)distanceKm * rate.RatePerKm);
        var timeFare = Math.Ceiling((decimal)estimatedDurationMin * rate.RatePerMin);
        var subtotal = rate.BaseFare + distanceFare + timeFare;

        // Apply surge to the ride portion (base + distance + time), not the platform fee
        var surgedSubtotal = Math.Ceiling(subtotal * surge);

        // Enforce minimum fare
        var fare = Math.Max(surgedSubtotal, rate.MinFare);
        var total = fare + _options.PlatformBookingFee;

        return new RidePricing(
            Fare: fare,
            PlatformBookingFee: _options.PlatformBookingFee,
            TotalAmount: total,
            DriverEarnings: fare,
            BaseFare: rate.BaseFare,
            DistanceFare: distanceFare,
            TimeFare: timeFare,
            SurgeMultiplier: surge,
            SurgeReason: surgeReason);
    }

    public int EstimateDurationMin(double distanceKm, VehicleType vehicleType)
    {
        var rate = _options.GetRate(vehicleType);
        return (int)Math.Ceiling(distanceKm / rate.AvgSpeedKmh * 60);
    }

    public SosPricing CalculateSosFare(decimal baseDistanceFare)
    {
        var grossSosFare = baseDistanceFare * _options.SosGrossMultiplier;
        var driverPayout = baseDistanceFare * _options.SosDriverMultiplier;
        var platformEmergencyFee = baseDistanceFare * _options.SosPlatformMultiplier;

        return new SosPricing(
            GrossSosFare: grossSosFare,
            DriverPayout: driverPayout,
            PlatformEmergencyFee: platformEmergencyFee,
            TotalAmount: grossSosFare);
    }
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
