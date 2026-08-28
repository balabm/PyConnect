namespace PondyConnect.Application.Features.FoodDelivery;

using Microsoft.Extensions.Options;

/// <summary>
/// Transparent pricing engine for food delivery.
/// VendorPayout = SubTotal (100%). PlatformFee is configurable. DeliveryFee is flat (configurable).
/// GST rate is configurable. LateNightDriverBonus applies for orders between 11 PM and 3 AM IST.
/// All values come from <see cref="FoodPricingOptions"/> (bound to "Pricing:Food" config section).
/// </summary>
public sealed class OrderPricingService
{
    private readonly FoodPricingOptions _options;

    public OrderPricingService(IOptions<FoodPricingOptions> options)
    {
        _options = options.Value;
    }

    public decimal DeliveryFeeFlat => _options.DeliveryFeeFlat;
    public decimal LateNightDriverBonus => _options.LateNightDriverBonus;
    public decimal PlatformFee => _options.PlatformFee;
    public decimal GstRate => _options.GstRate;
    public decimal PrimeMaxRadiusKm => _options.PrimeMaxRadiusKm;
    public decimal PrimeDistanceSurchargePerKm => _options.PrimeDistanceSurchargePerKm;
    public decimal PrimeMinOrderAmount => _options.PrimeMinOrderAmount;

    public OrderPricing CalculatePricing(decimal subTotal, bool isProMember, DateTimeOffset orderTime)
    {
        return CalculatePricing(subTotal, isProMember, orderTime, distanceKm: null);
    }

    /// <summary>
    /// Calculates pricing with Prime distance surcharge support.
    /// Prime members get free delivery within PrimeMaxRadiusKm.
    /// Beyond that, they pay a per-km surcharge to compensate the captain.
    /// </summary>
    public OrderPricing CalculatePricing(
        decimal subTotal,
        bool isProMember,
        DateTimeOffset orderTime,
        double? distanceKm = null)
    {
        var istTime = orderTime.AddMinutes(330); // UTC+5:30
        var hour = istTime.Hour;
        var isLateNight = hour >= 23 || hour < 3;

        decimal deliveryFee;
        decimal distanceSurcharge = 0m;

        if (isProMember && subTotal >= _options.PrimeMinOrderAmount)
        {
            // Prime free delivery within radius, surcharge beyond
            if (distanceKm.HasValue && (decimal)distanceKm.Value > _options.PrimeMaxRadiusKm)
            {
                var extraDistance = (decimal)distanceKm.Value - _options.PrimeMaxRadiusKm;
                distanceSurcharge = extraDistance * _options.PrimeDistanceSurchargePerKm;
                deliveryFee = distanceSurcharge; // Prime covers base, user pays extra distance
            }
            else
            {
                deliveryFee = 0m;
            }
        }
        else
        {
            deliveryFee = _options.DeliveryFeeFlat;
        }

        var driverBonus = isLateNight ? _options.LateNightDriverBonus : 0m;
        var taxes = subTotal * _options.GstRate;
        var total = subTotal + deliveryFee + driverBonus + _options.PlatformFee + taxes;

        return new OrderPricing(
            SubTotal: subTotal,
            DeliveryFee: deliveryFee,
            LateNightDriverBonus: driverBonus,
            Taxes: taxes,
            PlatformFee: _options.PlatformFee,
            TotalAmount: total,
            DistanceSurcharge: distanceSurcharge);
    }
}

public sealed record OrderPricing(
    decimal SubTotal,
    decimal DeliveryFee,
    decimal LateNightDriverBonus,
    decimal Taxes,
    decimal PlatformFee,
    decimal TotalAmount,
    decimal DistanceSurcharge = 0m);
