namespace PondyConnect.Application.Features.RideHailing;

/// <summary>
/// Configurable pricing options for ride hailing.
/// Bound to the "Pricing:Ride" section in appsettings.json.
/// All values can be overridden via environment variables
/// (Pricing__Ride__PlatformBookingFee, etc.) without code changes.
/// </summary>
public sealed class RidePricingOptions
{
    public decimal PlatformBookingFee { get; set; } = 15m;
    public decimal MaxSurgeMultiplier { get; set; } = 1.5m;
    public decimal SosGrossMultiplier { get; set; } = 2.5m;
    public decimal SosDriverMultiplier { get; set; } = 2.2m;
    public decimal SosPlatformMultiplier { get; set; } = 0.3m;
    public decimal CommissionRate { get; set; } = 0.1m;
    public decimal CancellationFeeNoShow { get; set; } = 50m;
    public decimal CancellationFeeEnRoute { get; set; } = 25m;
    public decimal CancellationFeeArrived { get; set; } = 50m;
    public decimal CompletionOtpThresholdAmount { get; set; } = 1000m;

    public VehicleRate Bike { get; set; } = new()
    {
        BaseFare = 15m, RatePerKm = 8m, RatePerMin = 1m, MinFare = 30m, AvgSpeedKmh = 25,
    };
    public VehicleRate Auto { get; set; } = new()
    {
        BaseFare = 25m, RatePerKm = 12m, RatePerMin = 1.5m, MinFare = 50m, AvgSpeedKmh = 18,
    };
    public VehicleRate Car { get; set; } = new()
    {
        BaseFare = 40m, RatePerKm = 15m, RatePerMin = 2m, MinFare = 70m, AvgSpeedKmh = 22,
    };

    public VehicleRate GetRate(Domain.Enums.VehicleType vehicleType) => vehicleType switch
    {
        Domain.Enums.VehicleType.Bike => Bike,
        Domain.Enums.VehicleType.Auto => Auto,
        Domain.Enums.VehicleType.Car => Car,
        _ => Bike,
    };
}

public sealed class VehicleRate
{
    public decimal BaseFare { get; set; }
    public decimal RatePerKm { get; set; }
    public decimal RatePerMin { get; set; }
    public decimal MinFare { get; set; }
    public int AvgSpeedKmh { get; set; } = 25;
}
