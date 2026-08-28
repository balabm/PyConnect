namespace PondyConnect.Application.Features.FoodDelivery;

/// <summary>
/// Configurable pricing options for food delivery.
/// Bound to the "Pricing:Food" section in appsettings.json.
/// </summary>
public sealed class FoodPricingOptions
{
    public decimal DeliveryFeeFlat { get; set; } = 40m;
    public decimal LateNightDriverBonus { get; set; } = 30m;
    public decimal PlatformFee { get; set; } = 2m;
    public decimal GstRate { get; set; } = 0.05m;
    public decimal PrimeMaxRadiusKm { get; set; } = 5.0m;
    public decimal PrimeDistanceSurchargePerKm { get; set; } = 10.0m;
    public decimal PrimeMinOrderAmount { get; set; } = 149m;
    public decimal CommissionRate { get; set; } = 0.1m;
}
