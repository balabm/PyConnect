namespace PondyConnect.Architecture.Tests;

using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Vendor;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Infrastructure.Persistence;

/// <summary>
/// End-to-end application-flow tests for the B2B vendor portal using an
/// in-memory EF provider (no Postgres/Redis required). Verifies the happy
/// path from a verified OTP through venue + promo management.
/// </summary>
public sealed class VendorB2bFlowTests
{
    private static readonly Guid s_fuocoVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    private static ApplicationDbContext CreateContext()
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

private static Task<int> SeedFuocoAsync(ApplicationDbContext context)
    {
        context.Users.Add(User.Create("Ravi Kumar", "9000000001", UserRole.Vendor));
        var vendor = Vendor.CreateForSeed(
            s_fuocoVendorId,
            "Fuoco Pizzeria",
            VendorCategory.Restaurant,
            contactPhone: "9000000001",
            merchantReference: "FUOCO-001");
        vendor.Approve();
        context.Vendors.Add(vendor);
        return context.SaveChangesAsync();
    }

private sealed class FakeOtpService : IOtpService
    {
        public Task<string> IssueCodeAsync(string phone, CancellationToken ct = default) => Task.FromResult("123456");

        public Task<bool> VerifyCodeAsync(string phone, string code, CancellationToken ct = default)
            => Task.FromResult(code == "123456");

        public Task<string?> PeekCodeAsync(string phone, CancellationToken ct = default)
            => Task.FromResult<string?>("123456");
    }

    private sealed class FakeJwt : IJwtTokenFactory
    {
        public string CreateAccessToken(Guid userId, string phone, string role)
            => $"token-{role}-{phone}";
    }

    private sealed class FakeSms : ISmsSender
    {
        public Task SendAsync(string phone, string message, CancellationToken ct = default) => Task.CompletedTask;
    }

    private sealed class FakeUserStore : IUserResolver
    {
        public Task<User> GetOrCreateAsync(string name, string phone, UserRole role, CancellationToken ct = default)
        {
            var user = User.Create(name, phone, role);
            return Task.FromResult(user);
        }
    }

    private sealed class FakeCurrentUser : ICurrentUserService
    {
        public Guid? UserId => null;

        public string? Phone => "9000000001";

        public string? Role => "Vendor";
    }

    [Fact]
    public async Task Handler_LoginToVenueAndPromo_WorksEndToEnd()
    {
        using var context = CreateContext();
        await SeedFuocoAsync(context);

        var otp = new FakeOtpService();
        var jwt = new FakeJwt();
        var sms = new FakeSms();
        var users = new FakeUserStore();
        var currentUser = new FakeCurrentUser();

        // 1. Login (vendor-scoped JWT)
        var loginHandler = new VerifyVendorOtpHandler(otp, jwt, users, context);
        var login = await loginHandler.Handle(new VerifyVendorOtpCommand("9000000001", "123456", "Ravi Kumar"), CancellationToken.None);

        login.VendorId.Should().Be(s_fuocoVendorId);
        login.VendorName.Should().Be("Fuoco Pizzeria");
        login.AccessToken.Should().Contain("Vendor");

        // 2. Venue management
        var createVenue = new CreateVendorVenueHandler(context, currentUser);
        var created = await createVenue.Handle(new CreateVendorVenueCommand(
            Name: "Fuoco Pizzeria",
            Category: VenueCategory.Pizzeria,
            Latitude: 11.9348,
            Longitude: 79.8346,
            MaxCapacity: 80,
            Description: "Wood-fired pizzas",
            Address: "Rue de la Marine, White Town",
            OperatingHours: new[]
            {
                new OperatingDayDto(DayOfWeek.Monday, new TimeOnly(12, 0), new TimeOnly(23, 0)),
                new OperatingDayDto(DayOfWeek.Friday, new TimeOnly(12, 0), new TimeOnly(23, 30))
            }), CancellationToken.None);

        created.VenueId.Should().NotBeEmpty();

        var listVenus = await new ListVendorVenuesHandler(context, currentUser)
            .Handle(new ListVendorVenuesQuery(), CancellationToken.None);
        listVenus.Should().ContainSingle(v => v.VenueId == created.VenueId && v.Name == "Fuoco Pizzeria");
        listVenus.Should().ContainSingle(v => v.OperatingHours.Count == 2);

        // 3. Update venue (change hours + capacity)
        var updateHandler = new UpdateVendorVenueHandler(context, currentUser);
        await updateHandler.Handle(new UpdateVendorVenueCommand(
            VenueId: created.VenueId,
            Name: "Fuoco Pizzeria",
            Category: VenueCategory.Pizzeria,
            Latitude: 11.9348,
            Longitude: 79.8346,
            MaxCapacity: 100,
            OperatingHours: new[]
            {
                new OperatingDayDto(DayOfWeek.Saturday, new TimeOnly(12, 0), new TimeOnly(23, 30))
            }), CancellationToken.None);

        var afterUpdate = await new ListVendorVenuesHandler(context, currentUser)
            .Handle(new ListVendorVenuesQuery(), CancellationToken.None);
        afterUpdate.Single(v => v.VenueId == created.VenueId).MaxCapacity.Should().Be(100);
        afterUpdate.Single(v => v.VenueId == created.VenueId).OperatingHours.Should().ContainSingle(h => h.DayOfWeek == DayOfWeek.Saturday);

        // 4. Promotion creation
        var promoHandler = new CreateVendorPromotionHandler(context, currentUser);
        var promo = await promoHandler.Handle(new CreateVendorPromotionCommand(
            PromoType: PromoType.PushNotification,
            Title: "Happy Hour 1+1 this weekend",
            Cost: 0,
            StartsAt: DateTimeOffset.UtcNow.AddHours(-1),
            ExpiresAt: DateTimeOffset.UtcNow.AddDays(3),
            Description: "Two wood-fired pizzas for the price of one.",
            TargetLatitude: 11.9348,
            TargetLongitude: 79.8346,
            TargetRadiusKm: 2), CancellationToken.None);

        promo.PromotionId.Should().NotBeEmpty();

        var promos = await new ListVendorPromotionsHandler(context, currentUser)
            .Handle(new ListVendorPromotionsQuery(), CancellationToken.None);
        promos.Should().ContainSingle(p => p.PromotionId == promo.PromotionId && p.Title == "Happy Hour 1+1 this weekend");

        // 5. Deactivate venue
        var deactivate = new DeactivateVendorVenueHandler(context, currentUser);
        await deactivate.Handle(new DeactivateVendorVenueCommand(created.VenueId), CancellationToken.None);
        var finalVenues = await new ListVendorVenuesHandler(context, currentUser)
            .Handle(new ListVendorVenuesQuery(), CancellationToken.None);
        finalVenues.Single(v => v.VenueId == created.VenueId).IsActive.Should().BeFalse();
    }

    [Fact]
    public async Task Login_ReturnsPendingForUnapprovedVendor()
    {
        using var context = CreateContext();
        context.Vendors.Add(Vendor.Create("Unapproved Shop", VendorCategory.Cafe, contactPhone: "9999999999"));
        await context.SaveChangesAsync();

        var handler = new VerifyVendorOtpHandler(new FakeOtpService(), new FakeJwt(), new FakeUserStore(), context);

        var result = await handler.Handle(new VerifyVendorOtpCommand("9999999999", "123456", "Owner"), CancellationToken.None);
        result.Status.Should().Be("Pending");
    }
}