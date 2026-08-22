namespace PondyConnect.Application.Features.FoodDelivery;

/// <summary>
/// Transparent pricing engine for food delivery.
/// VendorPayout = SubTotal (100%). PlatformFee = ₹2. DeliveryFee = flat ₹40.
/// GST = 5% on subTotal. LateNightDriverBonus = ₹30 for orders between 11 PM and 3 AM IST.
/// </summary>
public static class OrderPricingService
{
    public const decimal DeliveryFeeFlat = 40m;
    public const decimal LateNightDriverBonus = 30m;
    public const decimal PlatformFee = 2m;
    public const decimal GstRate = 0.05m;

    /// <summary>
    /// Prime members get free delivery only within this radius (km).
    /// Beyond this, a distance surcharge covers the captain's long haul.
    /// </summary>
    public const decimal PrimeMaxRadiusKm = 5.0m;

    /// <summary>
    /// Per-km surcharge for Prime orders beyond PrimeMaxRadiusKm.
    /// Ensures the captain is fairly compensated for the long haul.
    /// </summary>
    public const decimal PrimeDistanceSurchargePerKm = 10.0m;

    /// <summary>
    /// Minimum order subtotal for Prime free delivery to apply.
    /// </summary>
    public const decimal PrimeMinOrderAmount = 149m;

    public static OrderPricing CalculatePricing(decimal subTotal, bool isProMember, DateTimeOffset orderTime)
    {
        return CalculatePricing(subTotal, isProMember, orderTime, distanceKm: null);
    }

    /// <summary>
    /// Calculates pricing with Prime distance surcharge support.
    /// Prime members get free delivery within PrimeMaxRadiusKm.
    /// Beyond that, they pay a per-km surcharge to compensate the captain.
    /// </summary>
    public static OrderPricing CalculatePricing(
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

        if (isProMember && subTotal >= PrimeMinOrderAmount)
        {
            // Prime free delivery within radius, surcharge beyond
            if (distanceKm.HasValue && (decimal)distanceKm.Value > PrimeMaxRadiusKm)
            {
                var extraDistance = (decimal)distanceKm.Value - PrimeMaxRadiusKm;
                distanceSurcharge = extraDistance * PrimeDistanceSurchargePerKm;
                deliveryFee = distanceSurcharge; // Prime covers base, user pays extra distance
            }
            else
            {
                deliveryFee = 0m;
            }
        }
        else
        {
            deliveryFee = DeliveryFeeFlat;
        }

        var driverBonus = isLateNight ? LateNightDriverBonus : 0m;
        var taxes = subTotal * GstRate;
        var total = subTotal + deliveryFee + driverBonus + PlatformFee + taxes;

        return new OrderPricing(
            SubTotal: subTotal,
            DeliveryFee: deliveryFee,
            LateNightDriverBonus: driverBonus,
            Taxes: taxes,
            PlatformFee: PlatformFee,
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
 