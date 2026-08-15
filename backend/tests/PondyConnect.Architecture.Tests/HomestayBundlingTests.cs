namespace PondyConnect.Architecture.Tests;

using PondyConnect.Application.Features.Homestays;
using PondyConnect.Domain.Entities;
using Xunit;

public sealed class HomestayBundlingTests
{
    [Fact]
    public void SuggestAddOns_WhenNoTransitBooking_SuggestsScooterPickup()
    {
        var checkIn = new DateTimeOffset(2026, 8, 15, 12, 0, 0, TimeSpan.FromHours(5.5));

        var suggestions = StayBundlingService.GenerateAddOnSuggestions(checkIn, hasTransitBooking: false, hasLuggageBooking: false);

        var scooter = Assert.Single(suggestions, s => s.Name.Contains("Scooter"));
        Assert.False(scooter.IsFree);
        Assert.Equal(10m, scooter.DiscountPercentage);
    }

    [Fact]
    public void SuggestAddOns_AlwaysSuggestsLuggageCloak_Free()
    {
        var checkIn = new DateTimeOffset(2026, 8, 15, 12, 0, 0, TimeSpan.FromHours(5.5));

        var suggestions = StayBundlingService.GenerateAddOnSuggestions(checkIn, hasTransitBooking: false, hasLuggageBooking: false);

        var luggage = Assert.Single(suggestions, s => s.Name.Contains("Luggage"));
        Assert.True(luggage.IsFree);
        Assert.Equal(0m, luggage.Price);
    }

    [Fact]
    public void SuggestAddOns_WhenTransitAlreadyBooked_NoScooterSuggestion()
    {
        var checkIn = new DateTimeOffset(2026, 8, 15, 12, 0, 0, TimeSpan.FromHours(5.5));

        var suggestions = StayBundlingService.GenerateAddOnSuggestions(checkIn, hasTransitBooking: true, hasLuggageBooking: false);

        Assert.DoesNotContain(suggestions, s => s.Name.Contains("Scooter"));
        Assert.Single(suggestions, s => s.Name.Contains("Luggage"));
    }

    [Fact]
    public void SuggestAddOns_WhenLuggageAlreadyBooked_NoLuggageSuggestion()
    {
        var checkIn = new DateTimeOffset(2026, 8, 15, 12, 0, 0, TimeSpan.FromHours(5.5));

        var suggestions = StayBundlingService.GenerateAddOnSuggestions(checkIn, hasTransitBooking: false, hasLuggageBooking: true);

        Assert.DoesNotContain(suggestions, s => s.Name.Contains("Luggage"));
        Assert.Single(suggestions, s => s.Name.Contains("Scooter"));
    }

    [Fact]
    public void Homestay_Create_SetsDefaultValues()
    {
        var homestay = Homestay.Create(
            hostId: Guid.NewGuid(),
            name: "Test Villa",
            description: "A beautiful test villa",
            locationArea: "White Town",
            latitude: 11.93,
            longitude: 79.83,
            nightlyRate: 2000m,
            maxGuests: 4,
            hasWifi: true);

        Assert.Equal("Test Villa", homestay.Name);
        Assert.Equal("White Town", homestay.LocationArea);
        Assert.Equal(2000m, homestay.NightlyRate);
        Assert.Equal(4, homestay.MaxGuests);
        Assert.True(homestay.HasWifi);
        Assert.False(homestay.IsVerified);
    }

    [Fact]
    public void Homestay_Verify_SetsIsVerifiedTrue()
    {
        var homestay = Homestay.Create(
            hostId: Guid.NewGuid(),
            name: "Test Villa",
            description: "A beautiful test villa",
            locationArea: "White Town",
            latitude: 11.93,
            longitude: 79.83,
            nightlyRate: 2000m,
            maxGuests: 4);

        homestay.Verify();

        Assert.True(homestay.IsVerified);
    }

    [Fact]
    public void RoomAvailability_Lock_SetsIsBookedAndBookingId()
    {
        var availability = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 8, 15));
        var bookingId = Guid.NewGuid();

        availability.Lock(bookingId);

        Assert.True(availability.IsBooked);
        Assert.Equal(bookingId, availability.LockedByBookingId);
    }

    [Fact]
    public void RoomAvailability_Lock_OnAlreadyBooked_Throws()
    {
        var availability = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 8, 15));
        availability.Lock(Guid.NewGuid());

        Assert.Throws<InvalidOperationException>(() => availability.Lock(Guid.NewGuid()));
    }

    [Fact]
    public void RoomAvailability_Unlock_ClearsBooking()
    {
        var availability = RoomAvailability.Create(Guid.NewGuid(), new DateOnly(2026, 8, 15));
        availability.Lock(Guid.NewGuid());

        availability.Unlock();

        Assert.False(availability.IsBooked);
        Assert.Null(availability.LockedByBookingId);
    }

    [Fact]
    public void StayBundlingService_StandardCheckInTime_IsNoon()
    {
        Assert.Equal(new TimeSpan(12, 0, 0), StayBundlingService.StandardCheckInTime);
    }
}
