namespace PondyConnect.Architecture.Tests;

using FluentAssertions;
using Microsoft.Extensions.Options;
using PondyConnect.Application.Features.Auth;
using PondyConnect.Application.Features.FoodDelivery;
using PondyConnect.Application.Features.GeoFence;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Application.Features.Settlement;
using PondyConnect.Application.Features.Support;
using PondyConnect.Application.Features.Telemetry;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Application.Features.Wallet;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class OrderPricingServiceTests
{
    [Fact]
    public void CalculatePricing_NormalOrder_HasDeliveryFeeAndPlatformFee()
    {
        var pricing = OrderPricingService.CalculatePricing(
            subTotal: 300m, isProMember: false,
            orderTime: new DateTimeOffset(2026, 1, 15, 10, 0, 0, TimeSpan.Zero));

        pricing.SubTotal.Should().Be(300m);
        pricing.DeliveryFee.Should().Be(40m);
        pricing.LateNightDriverBonus.Should().Be(0m);
        pricing.Taxes.Should().Be(15m);
        pricing.PlatformFee.Should().Be(2m);
        pricing.TotalAmount.Should().Be(357m);
    }

    [Fact]
    public void CalculatePricing_ProMember_HasZeroDeliveryFee()
    {
        var pricing = OrderPricingService.CalculatePricing(
            subTotal: 300m, isProMember: true,
            orderTime: new DateTimeOffset(2026, 1, 15, 10, 0, 0, TimeSpan.Zero));

        pricing.DeliveryFee.Should().Be(0m);
        pricing.Taxes.Should().Be(15m);
        pricing.TotalAmount.Should().Be(317m);
    }

    [Fact]
    public void CalculatePricing_LateNight_HasDriverBonus()
    {
        // 11 PM IST = 17:30 UTC → hour = 17:30 + 5:30 = 23
        var pricing = OrderPricingService.CalculatePricing(
            subTotal: 300m, isProMember: false,
            orderTime: new DateTimeOffset(2026, 1, 15, 17, 30, 0, TimeSpan.Zero));

        pricing.LateNightDriverBonus.Should().Be(30m);
        pricing.Taxes.Should().Be(15m);
        pricing.TotalAmount.Should().Be(387m);
    }

    [Fact]
    public void CalculatePricing_NonLateNight_HasZeroDriverBonus()
    {
        // 2 PM IST = 08:30 UTC → hour = 14
        var pricing = OrderPricingService.CalculatePricing(
            subTotal: 300m, isProMember: false,
            orderTime: new DateTimeOffset(2026, 1, 15, 8, 30, 0, TimeSpan.Zero));

        pricing.LateNightDriverBonus.Should().Be(0m);
    }
}

public sealed class RidePricingServiceTests
{
    [Fact]
    public void CalculateFare_Bike_UsesBasePlusDistancePlusTime()
    {
        var pricing = RidePricingService.CalculateFare(5.0, VehicleType.Bike);

        // Base=15, Distance=5×8=40, Time=12min×1=12, Subtotal=67, Surge=1.0
        pricing.Fare.Should().Be(67m);
        pricing.PlatformBookingFee.Should().Be(15m);
        pricing.TotalAmount.Should().Be(82m);
        pricing.DriverEarnings.Should().Be(67m);
        pricing.BaseFare.Should().Be(15m);
        pricing.DistanceFare.Should().Be(40m);
        pricing.TimeFare.Should().Be(12m);
        pricing.SurgeMultiplier.Should().Be(1.0m);
    }

    [Fact]
    public void CalculateFare_Auto_UsesBasePlusDistancePlusTime()
    {
        var pricing = RidePricingService.CalculateFare(5.0, VehicleType.Auto);

        // Base=25, Distance=5×12=60, Time=17min×1.5=25.5→26, Subtotal=111
        pricing.Fare.Should().Be(111m);
        pricing.DriverEarnings.Should().Be(111m);
    }

    [Fact]
    public void CalculateFare_Car_UsesBasePlusDistancePlusTime()
    {
        var pricing = RidePricingService.CalculateFare(5.0, VehicleType.Car);

        // Base=40, Distance=5×15=75, Time=14min×2=28, Subtotal=143
        pricing.Fare.Should().Be(143m);
        pricing.DriverEarnings.Should().Be(143m);
    }

    [Fact]
    public void CalculateFare_WithSurge_CapsAt1Point5x()
    {
        var pricing = RidePricingService.CalculateFareWithSurge(5.0, 12, VehicleType.Bike, 3.0m, "High demand");

        // Subtotal=67, Surge capped at 1.5x → 67×1.5=100.5→101
        pricing.Fare.Should().Be(101m);
        pricing.SurgeMultiplier.Should().Be(1.5m);
        pricing.SurgeReason.Should().Be("High demand");
    }

    [Fact]
    public void CalculateFare_BelowMinimumFare_EnforcesMinimum()
    {
        var pricing = RidePricingService.CalculateFare(0.5, VehicleType.Bike);

        // Base=15, Distance=0.5×8=4, Time=2min×1=2, Subtotal=21 < MinFare=30
        pricing.Fare.Should().Be(30m);
    }

    [Fact]
    public void EstimateDurationMin_Bike_Uses25KmhSpeed()
    {
        var duration = RidePricingService.EstimateDurationMin(5.0, VehicleType.Bike);

        // 5km / 25kmh * 60 = 12
        duration.Should().Be(12);
    }

    [Fact]
    public void CalculateSosFare_WithBaseFare100_ReturnsCorrectSplit()
    {
        var sos = RidePricingService.CalculateSosFare(100m);

        sos.GrossSosFare.Should().Be(250m);
        sos.DriverPayout.Should().Be(220m);
        sos.PlatformEmergencyFee.Should().Be(30m);
        sos.TotalAmount.Should().Be(250m);
    }
}

public sealed class SurgeCalculatorTests
{
    [Theory]
    [InlineData(0, 0, 1.0, null)]
    [InlineData(1, 5, 1.0, null)]
    [InlineData(5, 2, 1.2, "Busy period — surge at 1.2x")]
    [InlineData(10, 2, 1.5, "High demand in your area — surge capped at 1.5x")]
    [InlineData(10, 0, 1.5, "High demand in your area — surge capped at 1.5x")]
    public void CalculateFromRatio_ReturnsCorrectMultiplier(int requests, int drivers, decimal expectedMultiplier, string? expectedReason)
    {
        var (multiplier, reason) = SurgeCalculator.CalculateFromRatio(requests, drivers);

        multiplier.Should().Be(expectedMultiplier);
        if (expectedReason is null)
            reason.Should().BeNull();
        else
            reason.Should().Be(expectedReason);
    }

    [Fact]
    public void CalculateFromRatio_NeverExceeds1Point5x()
    {
        var (multiplier, _) = SurgeCalculator.CalculateFromRatio(100, 1);

        multiplier.Should().Be(1.5m);
    }
}

public sealed class PromoCreditServiceTests
{
    [Fact]
    public void CalculateMaxApplicable_CapsAt20Percent()
    {
        var result = PromoCreditService.CalculateMaxApplicable(
            transactionTotal: 500m, promoBalance: 200m);

        // 20% of 500 = 100, which is less than 200
        result.Should().Be(100m);
    }

    [Fact]
    public void CalculateMaxApplicable_LimitedByPromoBalance()
    {
        var result = PromoCreditService.CalculateMaxApplicable(
            transactionTotal: 500m, promoBalance: 50m);

        // 20% of 500 = 100, but balance is only 50
        result.Should().Be(50m);
    }

    [Fact]
    public void SplitPayment_ReturnsCorrectPortions()
    {
        var split = PromoCreditService.SplitPayment(500m, 200m);

        split.PromoPortion.Should().Be(100m);
        split.OutOfPocketPortion.Should().Be(400m);
    }

    [Fact]
    public void CalculateMaxApplicable_WithNegativeInput_Throws()
    {
        var act = () => PromoCreditService.CalculateMaxApplicable(-100m, 50m);
        act.Should().Throw<ArgumentOutOfRangeException>();
    }
}

public sealed class ServiceAreaValidatorTests
{
    private static ServiceAreaValidator CreateValidator(double? radiusKm = null)
    {
        var options = new ServiceAreaOptions
        {
            CenterLatitude = 11.9356,
            CenterLongitude = 79.8301,
            RadiusKm = radiusKm ?? 50.0
        };
        return new ServiceAreaValidator(Options.Create(options));
    }

    [Fact]
    public void ValidateLocation_WithinZone_ReturnsTrue()
    {
        var validator = CreateValidator();
        var result = validator.ValidateLocation(GeoLocation.Create(11.936, 79.831));

        result.IsWithinZone.Should().BeTrue();
        result.DistanceKm.Should().BeLessThan(50.0);
    }

    [Fact]
    public void ValidateLocation_OutsideZone_ReturnsFalse()
    {
        var validator = CreateValidator();
        var result = validator.ValidateLocation(GeoLocation.Create(12.5, 80.0));

        result.IsWithinZone.Should().BeFalse();
        result.DistanceKm.Should().BeGreaterThan(50.0);
    }

    [Fact]
    public void EnsureWithinZone_OutsideZone_ThrowsServiceAreaException()
    {
        var validator = CreateValidator();
        var act = () => validator.EnsureWithinZone(GeoLocation.Create(12.5, 80.0));

        act.Should().Throw<ServiceAreaException>();
    }

    [Fact]
    public void Center_ReturnsConfiguredLocation()
    {
        var validator = CreateValidator();

        validator.Center.Latitude.Should().Be(11.9356);
        validator.Center.Longitude.Should().Be(79.8301);
        validator.RadiusKm.Should().Be(50.0);
    }
}

public sealed class SettlementCalculationServiceTests
{
    [Fact]
    public void CalculateForRide_SetsDriverPayoutAndPlatformFee()
    {
        var result = SettlementCalculationService.CalculateForRide(
            paymentId: Guid.NewGuid(), rideRequestId: Guid.NewGuid(),
            fare: 100m, platformBookingFee: 15m);

        result.GrossAmount.Should().Be(115m);
        result.DriverPayout.Should().Be(100m);
        result.PlatformFee.Should().Be(15m);
        result.VendorPayout.Should().Be(0m);
        result.RideRequestId.Should().NotBeNull();
    }

    [Fact]
    public void CalculateForFoodOrder_SplitsVendorAndDriver()
    {
        var result = SettlementCalculationService.CalculateForFoodOrder(
            paymentId: Guid.NewGuid(), foodOrderId: Guid.NewGuid(),
            subTotal: 300m, deliveryFee: 40m, lateNightBonus: 30m, platformFee: 0m);

        result.GrossAmount.Should().Be(370m);
        result.VendorPayout.Should().Be(300m);
        result.DriverPayout.Should().Be(70m);
        result.PlatformFee.Should().Be(0m);
        result.FoodOrderId.Should().NotBeNull();
    }

    [Fact]
    public void CalculateForRental_SplitsVendorAndPlatform()
    {
        var result = SettlementCalculationService.CalculateForRental(
            paymentId: Guid.NewGuid(), rentalId: Guid.NewGuid(),
            totalAmount: 300m);

        result.GrossAmount.Should().Be(300m);
        result.VendorPayout.Should().Be(250m);
        result.PlatformFee.Should().Be(50m);
        result.DriverPayout.Should().Be(0m);
        result.ScooterRentalId.Should().NotBeNull();
    }
}

public sealed class MockLlmServiceTests
{
    private readonly MockLlmService _service = new();

    [Fact]
    public async Task GenerateResponse_WithCriticalKeyword_ReturnsCritical()
    {
        var result = await _service.GenerateResponseAsync("system", "I had an accident!", default);

        result.IsCritical.Should().BeTrue();
        result.DetectedIntent.Should().StartWith("Critical:");
        result.Reply.Should().Contain("emergency");
    }

    [Fact]
    public async Task GenerateResponse_WithTransactionalKeyword_ReturnsTransactional()
    {
        var result = await _service.GenerateResponseAsync("system", "I need a refund for my booking", default);

        result.IsCritical.Should().BeFalse();
        result.DetectedIntent.Should().StartWith("Transactional:");
        result.Reply.Should().Contain("refund");
    }

    [Fact]
    public async Task GenerateResponse_WithGenericMessage_ReturnsInfo()
    {
        var result = await _service.GenerateResponseAsync("system", "What services do you offer?", default);

        result.IsCritical.Should().BeFalse();
        result.DetectedIntent.Should().Be("Info");
    }

    [Fact]
    public async Task GenerateResponse_WithCancelKeyword_DetectsTransactionalCancel()
    {
        var result = await _service.GenerateResponseAsync("system", "Please cancel my ride", default);

        result.IsCritical.Should().BeFalse();
        result.DetectedIntent.Should().Be("Transactional: cancel");
    }

    [Fact]
    public async Task GenerateResponse_CaseInsensitive_MatchesKeywords()
    {
        var result = await _service.GenerateResponseAsync("system", "I AM LOST AND STRANDED", default);

        result.IsCritical.Should().BeTrue();
    }

    [Fact]
    public async Task GenerateResponse_WithEmptyMessage_ReturnsInfo()
    {
        var result = await _service.GenerateResponseAsync("system", "", default);

        result.IsCritical.Should().BeFalse();
        result.DetectedIntent.Should().Be("Info");
    }
}

public sealed class ChannelTelemetryServiceTests
{
    [Fact]
    public async Task LogAsync_WritesToChannel()
    {
        var service = new ChannelTelemetryService();
        await service.LogAsync(Guid.NewGuid(), "session-1", "screen_view", "{}", default);

        var hasItem = service.Reader.TryRead(out var log);
        hasItem.Should().BeTrue();
        log!.EventName.Should().Be("screen_view");
        log.SessionId.Should().Be("session-1");
    }

    [Fact]
    public async Task LogAsync_WithNullUserId_CreatesLogWithNullUserId()
    {
        var service = new ChannelTelemetryService();
        await service.LogAsync(null, "session-2", "app_open", default);

        service.Reader.TryRead(out var log).Should().BeTrue();
        log!.UserId.Should().BeNull();
    }

    [Fact]
    public void Reader_IsAccessibleBeforeAnyWrites()
    {
        var service = new ChannelTelemetryService();
        service.Reader.Should().NotBeNull();
    }
}

public sealed class VerifyAadhaarValidatorTests
{
    [Fact]
    public void VerifyAadhaar_WithNon12Digit_FailsValidation()
    {
        var validator = new VerifyAadhaarValidator();
        var result = validator.Validate(new VerifyAadhaarCommand("12345"));

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void VerifyAadhaar_With12Digits_PassesValidation()
    {
        var validator = new VerifyAadhaarValidator();
        var result = validator.Validate(new VerifyAadhaarCommand("123456789012"));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void VerifyAadhaar_WithLetters_FailsValidation()
    {
        var validator = new VerifyAadhaarValidator();
        var result = validator.Validate(new VerifyAadhaarCommand("12345678901a"));

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void VerifyAadhaar_WithEmpty_FailsValidation()
    {
        var validator = new VerifyAadhaarValidator();
        var result = validator.Validate(new VerifyAadhaarCommand(""));

        result.IsValid.Should().BeFalse();
    }
}

public sealed class VendorAuthValidatorTests
{
    [Fact]
    public void RequestVendorOtp_WithInvalidPhone_FailsValidation()
    {
        var validator = new RequestVendorOtpCommandValidator();
        var result = validator.Validate(new RequestVendorOtpCommand("abc"));

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void RequestVendorOtp_WithValidPhone_PassesValidation()
    {
        var validator = new RequestVendorOtpCommandValidator();
        var result = validator.Validate(new RequestVendorOtpCommand("9000000001"));

        result.IsValid.Should().BeTrue();
    }

    [Fact]
    public void VerifyVendorOtp_WithShortOtp_FailsValidation()
    {
        var validator = new VerifyVendorOtpCommandValidator();
        var result = validator.Validate(new VerifyVendorOtpCommand("9000000001", "12"));

        result.IsValid.Should().BeFalse();
    }

    [Fact]
    public void VerifyVendorOtp_WithValidOtp_PassesValidation()
    {
        var validator = new VerifyVendorOtpCommandValidator();
        var result = validator.Validate(new VerifyVendorOtpCommand("9000000001", "123456"));

        result.IsValid.Should().BeTrue();
    }
}
