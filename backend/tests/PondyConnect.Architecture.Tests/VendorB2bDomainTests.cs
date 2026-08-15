namespace PondyConnect.Architecture.Tests;

using FluentAssertions;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

public sealed class VendorDomainTests
{
    [Fact]
    public void CreateForSeed_AssignsExplicitIdentity()
    {
        var id = Guid.Parse("00000000-0000-0000-0000-000000000001");
        var vendor = Vendor.CreateForSeed(id, "Fuoco Pizzeria", VendorCategory.Restaurant, "9000000001");

        vendor.Id.Should().Be(id);
        vendor.Name.Should().Be("Fuoco Pizzeria");
        vendor.Category.Should().Be(VendorCategory.Restaurant);
    }

    [Fact]
    public void Create_AlwaysGeneratesUniqueIdentities()
    {
        var a = Vendor.Create("A", VendorCategory.Cafe);
        var b = Vendor.Create("B", VendorCategory.Cafe);

        a.Id.Should().NotBe(b.Id);
    }

    [Fact]
    public void ApproveAndDeactivate_MarkUpdated()
    {
        var vendor = Vendor.Create("Test Shop", VendorCategory.LuggageCloak);

        vendor.Approve();
        vendor.IsApproved.Should().BeTrue();

        vendor.Deactivate();
        vendor.IsActive.Should().BeFalse();
    }
}

public sealed class VenueManagementDomainTests
{
    [Fact]
    public void UpdateDetails_And_Category_And_Location_ModifyProfile()
    {
        var venue = Venue.Create(
            "Old Name",
            VenueCategory.Cafe,
            GeoLocation.Create(11.93, 79.83),
            maxCapacity: 50);

        venue.UpdateDetails("New Name", "desc", "White Town");
        venue.UpdateCategory(VenueCategory.Restaurant);
        venue.UpdateLocation(GeoLocation.Create(11.94, 79.84));

        venue.Name.Should().Be("New Name");
        venue.Category.Should().Be(VenueCategory.Restaurant);
        venue.Location.Latitude.Should().Be(11.94);
        venue.Address.Should().Be("White Town");
    }

    [Fact]
    public void SetOperatingHours_ReplacesExistingSchedule()
    {
        var venue = Venue.Create("Test", VenueCategory.Cafe, GeoData.Create(10, 79), maxCapacity: 50);
        venue.AddAvailability(DayOfWeek.Monday, new TimeOnly(9, 0), new TimeOnly(17, 0));

        var replacement = new[]
        {
            VenueAvailability.Create(DayOfWeek.Wednesday, new TimeOnly(10, 0), new TimeOnly(22, 0)),
            VenueAvailability.Create(DayOfWeek.Friday, new TimeOnly(10, 0), new TimeOnly(22, 0))
        };
        venue.SetOperatingHours(replacement);

        venue.Availability.Should().HaveCount(2);
        venue.Availability.Should().AllSatisfy(a => a.OpensAt.Should().Be(new TimeOnly(10, 0)));
    }

    [Fact]
    public void ToggleActive_DeactivatesVenue()
    {
        var venue = Venue.Create("Test", VenueCategory.Cafe, GeoData.Create(10, 79), maxCapacity: 20);
        venue.ToggleActive(false);
        venue.IsActive.Should().BeFalse();
    }
}

public sealed class VendorPromotionDomainTests
{
    [Fact]
    public void Create_IsLiveWithinWindow()
    {
        var promotion = VendorPromotion.Create(
            Guid.NewGuid(),
            PromoType.PushNotification,
            "Happy Hour 1+1",
            cost: 0,
            startsAt: DateTimeOffset.UtcNow.AddMinutes(-5),
            expiresAt: DateTimeOffset.UtcNow.AddHours(2),
            description: "Two cocktails for the price of one.",
            targetLatitude: 11.9362,
            targetLongitude: 79.8346,
            targetRadiusKm: 2.0);

        promotion.IsValidAt(DateTimeOffset.UtcNow).Should().BeTrue();
        promotion.TargetRadiusKm.Should().Be(2.0);
        promotion.PromoType.Should().Be(PromoType.PushNotification);
    }

    [Fact]
    public void Create_RejectsBackwardsExpiry()
    {
        var start = DateTimeOffset.UtcNow;
        var act = () => VendorPromotion.Create(
            Guid.NewGuid(),
            PromoType.TopListing,
            "Bad promo",
            cost: 50,
            startsAt: start,
            expiresAt: start.AddMinutes(-1));

        act.Should().Throw<ArgumentException>();
    }
}

internal static class GeoData
{
    public static GeoLocation Create(double lat, double lng)
        => GeoLocation.Create(lat, lng);
}