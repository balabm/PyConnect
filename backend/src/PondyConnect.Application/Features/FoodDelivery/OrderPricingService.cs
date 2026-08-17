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

    public static OrderPricing CalculatePricing(decimal subTotal, bool isProMember, DateTimeOffset orderTime)
    {
        var istTime = orderTime.AddMinutes(330); // UTC+5:30
        var hour = istTime.Hour;
        var isLateNight = hour >= 23 || hour < 3;

        var deliveryFee = isProMember ? 0m : DeliveryFeeFlat;
        var driverBonus = isLateNight ? LateNightDriverBonus : 0m;
        var taxes = subTotal * GstRate;
        var total = subTotal + deliveryFee + driverBonus + PlatformFee + taxes;

        return new OrderPricing(
            SubTotal: subTotal,
            DeliveryFee: deliveryFee,
            LateNightDriverBonus: driverBonus,
            Taxes: taxes,
            PlatformFee: PlatformFee,
            TotalAmount: total);
    }
}

public sealed record OrderPricing(
    decimal SubTotal,
    decimal DeliveryFee,
    decimal LateNightDriverBonus,
    decimal Taxes,
    decimal PlatformFee,
    decimal TotalAmount);
 