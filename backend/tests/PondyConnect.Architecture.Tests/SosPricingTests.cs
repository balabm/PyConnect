namespace PondyConnect.Architecture.Tests;

using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Domain.Enums;
using Xunit;

public sealed class SosPricingTests
{
    [Fact]
    public void CalculateSosFare_WithBaseFare100_ReturnsCorrectSplit()
    {
        var sos = RidePricingService.CalculateSosFare(100m);

        Assert.Equal(250m, sos.GrossSosFare);
        Assert.Equal(220m, sos.DriverPayout);
        Assert.Equal(30m, sos.PlatformEmergencyFee);
        Assert.Equal(250m, sos.TotalAmount);
    }

    [Fact]
    public void CalculateSosFare_DriverPayoutPlusPlatformFee_EqualsGrossSosFare()
    {
        var sos = RidePricingService.CalculateSosFare(100m);

        Assert.Equal(sos.GrossSosFare, sos.DriverPayout + sos.PlatformEmergencyFee);
    }

    [Fact]
    public void CalculateSosFare_WithBaseFare50_ReturnsCorrectSplit()
    {
        var sos = RidePricingService.CalculateSosFare(50m);

        Assert.Equal(125m, sos.GrossSosFare);
        Assert.Equal(110m, sos.DriverPayout);
        Assert.Equal(15m, sos.PlatformEmergencyFee);
    }

    [Fact]
    public void CalculateSosFare_WithBaseFare0_ReturnsAllZeros()
    {
        var sos = RidePricingService.CalculateSosFare(0m);

        Assert.Equal(0m, sos.GrossSosFare);
        Assert.Equal(0m, sos.DriverPayout);
        Assert.Equal(0m, sos.PlatformEmergencyFee);
    }

    [Fact]
    public void CalculateSosFare_DriverEarningsExceedNormalFare()
    {
        const double distanceKm = 5.0;
        var normalPricing = RidePricingService.CalculateFare(distanceKm, VehicleType.Bike);
        var sosPricing = RidePricingService.CalculateSosFare(normalPricing.Fare);

        Assert.True(sosPricing.DriverPayout > normalPricing.Fare);
    }
}
