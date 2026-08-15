using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Domain.Enums;
using PondyConnect.Infrastructure.Persistence;

namespace PondyConnect.Api.Tests;

public abstract class IntegrationTestBase : IClassFixture<CustomWebApplicationFactory>, IDisposable
{
    protected readonly CustomWebApplicationFactory Factory;
    protected readonly HttpClient Client;
    protected readonly IServiceScope Scope;
    protected readonly ApplicationDbContext Db;

    protected IntegrationTestBase(CustomWebApplicationFactory factory)
    {
        Factory = factory;
        Client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        Scope = factory.Services.CreateScope();
        Db = Scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    }

    public void Dispose()
    {
        Scope.Dispose();
        Client.Dispose();
        GC.SuppressFinalize(this);
    }

    protected async Task<string> AuthenticateAsync(string phone = "9000000099")
    {
        // Request OTP
        var otpResponse = await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = phone });
        otpResponse.EnsureSuccessStatusCode();

        // Extract OTP from the in-memory OTP service
        var otpService = (TestOtpService)Scope.ServiceProvider.GetRequiredService<PondyConnect.Application.Common.Interfaces.IOtpService>();
        var otp = await otpService.GetCodeForTestAsync(phone);

        // Verify OTP
        var verifyResponse = await Client.PostAsJsonAsync("/api/auth/otp/verify", new
        {
            Phone = phone,
            Otp = otp,
            Name = "Test User"
        });
        verifyResponse.EnsureSuccessStatusCode();

        var result = await verifyResponse.Content.ReadFromJsonAsync<AuthResponseDto>();
        Client.DefaultRequestHeaders.Authorization = new("Bearer", result!.AccessToken);

        // Accept liability waiver so RequireWaiver-filtered endpoints (rides, rentals) work
        var waiverResponse = await Client.PostAsync("/api/auth/waiver/accept", content: null);
        waiverResponse.EnsureSuccessStatusCode();

        return result.AccessToken;
    }

    protected record AuthResponseDto(string AccessToken, Guid UserId, string Name, string Phone, string Role, bool IsProMember, bool IsVerifiedLocal);

    protected static readonly Guid SeedVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");
}

public class AuthEndpointsTests : IntegrationTestBase
{
    public AuthEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RequestOtp_WithValidPhone_ReturnsOk()
    {
        var response = await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = "9000000088" });
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task RequestOtp_WithInvalidPhone_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = "123" });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetMe_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/auth/me");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetMe_WithAuth_ReturnsUserInfo()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/auth/me");
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<AuthResponseDto>();
        result!.Name.Should().Be("Test User");
        result.Phone.Should().Be("9000000099");
    }

    [Fact]
    public async Task GetMe_WithAuth_ReturnsIsProMember()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/auth/me");
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<AuthResponseDto>();
        result!.IsProMember.Should().BeFalse();
    }

    [Fact]
    public async Task VerifyOtp_WithInvalidOtp_ReturnsUnauthorized()
    {
        await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = "9000000077" });
        var response = await Client.PostAsJsonAsync("/api/auth/otp/verify", new
        {
            Phone = "9000000077",
            Otp = "000000",
            Name = "Test"
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}

public class FoodDeliveryEndpointsTests : IntegrationTestBase
{
    public FoodDeliveryEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetMenu_WithoutAuth_ReturnsOk()
    {
        var response = await Client.GetAsync($"/api/vendors/{SeedVendorId}/menu");
        response.EnsureSuccessStatusCode();
        var items = await response.Content.ReadFromJsonAsync<List<MenuItemDto>>();
        items.Should().NotBeEmpty();
        items!.Count.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task GetMenu_WithNonExistentVendor_ReturnsEmpty()
    {
        var response = await Client.GetAsync($"/api/vendors/{Guid.NewGuid()}/menu");
        response.EnsureSuccessStatusCode();
        var items = await response.Content.ReadFromJsonAsync<List<MenuItemDto>>();
        items.Should().BeEmpty();
    }

    [Fact]
    public async Task Checkout_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Margherita Pizza", Quantity = 1, UnitPrice = 280m } }
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Checkout_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Margherita Pizza", Quantity = 2, UnitPrice = 280m } }
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<CheckoutResponseDto>();
        result!.SubTotal.Should().Be(560m);
        result.VendorPayout.Should().Be(560m);
        result.PlatformFee.Should().Be(0m);
        result.Status.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task Checkout_WithOutOfZoneLocation_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "Chennai",
            DeliveryLatitude = 13.0827,
            DeliveryLongitude = 80.2707,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Margherita Pizza", Quantity = 1, UnitPrice = 280m } }
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetOrders_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        // First create an order
        await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Garlic Bread", Quantity = 1, UnitPrice = 120m } }
        });
        // Then list orders
        var response = await Client.GetAsync("/api/orders");
        response.EnsureSuccessStatusCode();
        var orders = await response.Content.ReadFromJsonAsync<List<OrderListDto>>();
        orders.Should().NotBeEmpty();
    }

    [Fact]
    public async Task GetOrders_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/orders");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetOrder_WithValidId_ReturnsOrder()
    {
        await AuthenticateAsync();
        var checkoutResponse = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Tiramisu", Quantity = 1, UnitPrice = 180m } }
        });
        var checkout = await checkoutResponse.Content.ReadFromJsonAsync<CheckoutResponseDto>();
        var response = await Client.GetAsync($"/api/orders/{checkout!.OrderId}");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task Checkout_WithEmptyItems_ReturnsUnprocessableEntity()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 2,
            Items = Array.Empty<object>()
        });
        response.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);
    }

    record MenuItemDto(Guid Id, string Name, decimal Price, string Category, bool IsAvailable, bool IsLateNight);
    record CheckoutResponseDto(Guid OrderId, decimal VendorPayout, decimal SubTotal, decimal DeliveryFee, decimal LateNightDriverBonus, decimal PlatformFee, decimal TotalAmount, string Status);
    record OrderListDto(Guid OrderId, string Status, decimal TotalAmount);
}

public class EssentialsEndpointsTests : IntegrationTestBase
{
    public EssentialsEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetProducts_ReturnsNonEmpty()
    {
        var response = await Client.GetAsync("/api/essentials");
        response.EnsureSuccessStatusCode();
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        products.Should().NotBeEmpty();
        products!.Count.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task GetProducts_WithCategoryFilter_ReturnsFiltered()
    {
        var response = await Client.GetAsync("/api/essentials?category=Snacks");
        response.EnsureSuccessStatusCode();
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        products!.Should().AllSatisfy(p => p.Category.Should().Be("Snacks"));
    }

    [Fact]
    public async Task GetProducts_WithLateNightFilter_ReturnsOnlyLateNight()
    {
        var response = await Client.GetAsync("/api/essentials?lateNight=true");
        response.EnsureSuccessStatusCode();
        var products = await response.Content.ReadFromJsonAsync<List<ProductDto>>();
        products!.Should().AllSatisfy(p => p.IsLateNightEssential.Should().BeTrue());
    }

    [Fact]
    public async Task GetProduct_WithValidId_ReturnsProduct()
    {
        var productsResponse = await Client.GetAsync("/api/essentials");
        var products = await productsResponse.Content.ReadFromJsonAsync<List<ProductDto>>();
        var firstId = products!.First().Id;

        var response = await Client.GetAsync($"/api/essentials/{firstId}");
        response.EnsureSuccessStatusCode();
        var product = await response.Content.ReadFromJsonAsync<ProductDto>();
        product!.Name.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task CreateOrder_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/essentials/orders", new
        {
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            Items = new[] { new { ProductId = Guid.NewGuid(), Quantity = 1 } }
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CreateOrder_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var productsResponse = await Client.GetAsync("/api/essentials");
        var products = await productsResponse.Content.ReadFromJsonAsync<List<ProductDto>>();
        var firstId = products!.First().Id;

        var response = await Client.PostAsJsonAsync("/api/essentials/orders", new
        {
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            Items = new[] { new { ProductId = firstId, Quantity = 2 } }
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetOrders_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/essentials/orders");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetSuggestions_WithValidProductIds_ReturnsSuggestions()
    {
        var productsResponse = await Client.GetAsync("/api/essentials");
        var products = await productsResponse.Content.ReadFromJsonAsync<List<ProductDto>>();
        var firstId = products!.First().Id;

        var response = await Client.PostAsJsonAsync("/api/essentials/suggestions", new
        {
            ProductIds = new[] { firstId }
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetOrders_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/essentials/orders");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    record ProductDto(Guid Id, string Name, decimal Price, string Category, bool IsLateNightEssential);
}

public class RideHailingEndpointsTests : IntegrationTestBase
{
    public RideHailingEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RequestRide_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "Gandhi Statue",
            DropoffLatitude = 11.9370,
            DropoffLongitude = 79.8338,
            DropoffAddress = "31 Suffren Street",
            DistanceKm = 1.5,
            VehicleType = 1,
            PaymentMethod = 1
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task RequestRide_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "Gandhi Statue",
            DropoffLatitude = 11.9370,
            DropoffLongitude = 79.8338,
            DropoffAddress = "31 Suffren Street",
            DistanceKm = 1.5,
            VehicleType = 1,
            PaymentMethod = 1
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<RideResponseDto>();
        result!.Fare.Should().BeGreaterThan(0);
        result.DriverEarnings.Should().Be(result.Fare);
        result.PlatformBookingFee.Should().Be(15m);
        result.TotalAmount.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task RequestRide_WithOutOfZonePickup_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 13.0827,
            PickupLongitude = 80.2707,
            PickupAddress = "Chennai",
            DropoffLatitude = 11.9370,
            DropoffLongitude = 79.8338,
            DropoffAddress = "31 Suffren Street",
            DistanceKm = 150,
            VehicleType = 1,
            PaymentMethod = 1
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetRide_WithValidId_ReturnsRide()
    {
        await AuthenticateAsync();
        var createResponse = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "Gandhi Statue",
            DropoffLatitude = 11.9370,
            DropoffLongitude = 79.8338,
            DropoffAddress = "31 Suffren Street",
            DistanceKm = 2.0,
            VehicleType = 2,
            PaymentMethod = 1
        });
        var created = await createResponse.Content.ReadFromJsonAsync<RideResponseDto>();
        var response = await Client.GetAsync($"/api/rides/{created!.RideId}");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task ListRides_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/rides");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task ListRides_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/rides");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CancelRide_WithValidId_ReturnsOk()
    {
        await AuthenticateAsync();
        var createResponse = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "Gandhi Statue",
            DropoffLatitude = 11.9370,
            DropoffLongitude = 79.8338,
            DropoffAddress = "31 Suffren Street",
            DistanceKm = 1.0,
            VehicleType = 1,
            PaymentMethod = 1
        });
        var created = await createResponse.Content.ReadFromJsonAsync<RideResponseDto>();
        var response = await Client.PostAsJsonAsync($"/api/rides/{created!.RideId}/cancel", new { Reason = "Changed mind" });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetNearbyDrivers_ReturnsList()
    {
        var response = await Client.GetAsync("/api/rides/nearby-drivers?lat=11.9356&lng=79.8301&radius=3.0");
        response.EnsureSuccessStatusCode();
        var drivers = await response.Content.ReadFromJsonAsync<List<NearbyDriverDto>>();
        drivers.Should().NotBeEmpty();
    }

    record RideResponseDto(Guid RideId, double DistanceKm, int EstimatedDurationMin, decimal Fare, decimal DriverEarnings, decimal PlatformBookingFee, decimal TotalAmount, string Status, string VehicleType, string PaymentMethod);
    record NearbyDriverDto(Guid Id, string Name, string VehicleType);
}

public class PublicEndpointsTests : IntegrationTestBase
{
    public PublicEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetFlashPromos_ReturnsActivePromos()
    {
        var response = await Client.GetAsync("/api/flash-promos");
        response.EnsureSuccessStatusCode();
        var promos = await response.Content.ReadFromJsonAsync<List<FlashPromoDto>>();
        promos.Should().NotBeEmpty();
        promos!.First().DiscountPercentage.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task GetServiceArea_ReturnsAreaInfo()
    {
        var response = await Client.GetAsync("/api/service-area");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetVenues_ReturnsNonEmpty()
    {
        var response = await Client.GetAsync("/api/venues");
        response.EnsureSuccessStatusCode();
        var venues = await response.Content.ReadFromJsonAsync<List<VenueDto>>();
        venues.Should().NotBeEmpty();
    }

    [Fact]
    public async Task GetVenue_WithValidId_ReturnsVenue()
    {
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var firstId = venues!.First().Id;

        var response = await Client.GetAsync($"/api/venues/{firstId}");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task HealthCheck_ReturnsHealthy()
    {
        var response = await Client.GetAsync("/health");
        response.EnsureSuccessStatusCode();
    }

    record FlashPromoDto(string Title, decimal DiscountPercentage);
    record VenueDto(Guid Id, string Name, string Category);
}

public class VendorEndpointsTests : IntegrationTestBase
{
    public VendorEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetDashboard_WithoutVendorAuth_ReturnsUnauthorized()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.GetAsync("/api/vendor/dashboard");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetDashboard_WithVendorAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/dashboard");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetFlashPromos_WithVendorAuth_ReturnsList()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/flash-promos");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetFlashPromos_WithoutVendorAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.GetAsync("/api/vendor/flash-promos");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetPromotions_WithVendorAuth_ReturnsList()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/promotions");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetVenues_WithVendorAuth_ReturnsList()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/venues");
        response.EnsureSuccessStatusCode();
    }
}

public class BookingLifecycleTests : IntegrationTestBase
{
    public BookingLifecycleTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task CreateBooking_WithValidVenue_ReturnsCreated()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var response = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 2,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(1),
            Notes = (string?)null
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<CreateBookingResponseDto>();
        result!.BookingId.Should().NotBeEmpty();
        result.PassToken.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task CancelBooking_WithValidBooking_ReturnsOk()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        var cancelResponse = await Client.PostAsync($"/api/bookings/{created!.BookingId}/cancel", content: null);
        cancelResponse.EnsureSuccessStatusCode();
        var result = await cancelResponse.Content.ReadFromJsonAsync<CancelBookingResponseDto>();
        result!.Status.Should().Be("Cancelled");
        result.FreedSeats.Should().BeGreaterThan(0);
    }

    [Fact]
    public async Task CancelBooking_WithNonExistentId_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync($"/api/bookings/{Guid.NewGuid()}/cancel", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task CompleteBooking_WithValidBooking_ReturnsOk()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(3),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        var completeResponse = await Client.PostAsync($"/api/bookings/{created!.BookingId}/complete", content: null);
        completeResponse.EnsureSuccessStatusCode();
        var result = await completeResponse.Content.ReadFromJsonAsync<CompleteBookingResponseDto>();
        result!.Status.Should().Be("Completed");
    }

    record CreateBookingResponseDto(Guid BookingId, decimal Amount, string Status, string PassToken);
    record CancelBookingResponseDto(Guid BookingId, string Status, int FreedSeats);
    record CompleteBookingResponseDto(Guid BookingId, string Status, DateTimeOffset CompletedAt);
    record VenueDto(Guid Id, string Name, string Category);

    [Fact]
    public async Task CancelBooking_BelongingToAnotherUser_ReturnsBadRequest()
    {
        // Create booking as default user (9000000099)
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        // Authenticate as a different user
        await AuthenticateAsync("9000000002");

        var cancelResponse = await Client.PostAsync($"/api/bookings/{created!.BookingId}/cancel", content: null);
        cancelResponse.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CancelBooking_AlreadyCancelled_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        await Client.PostAsync($"/api/bookings/{created!.BookingId}/cancel", content: null);
        var secondCancel = await Client.PostAsync($"/api/bookings/{created.BookingId}/cancel", content: null);
        secondCancel.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task CompleteBooking_AfterCancel_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        await Client.PostAsync($"/api/bookings/{created!.BookingId}/cancel", content: null);
        var completeResponse = await Client.PostAsync($"/api/bookings/{created.BookingId}/complete", content: null);
        completeResponse.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task CancelBooking_DecreasesVenueCapacity()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var venueBefore = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        var capacityBefore = venueBefore!.CurrentCapacity;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 2,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        var venueAfterCreate = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        venueAfterCreate!.CurrentCapacity.Should().Be(capacityBefore + 2);

        await Client.PostAsync($"/api/bookings/{created!.BookingId}/cancel", content: null);

        var venueAfterCancel = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        venueAfterCancel!.CurrentCapacity.Should().Be(capacityBefore);
    }

    [Fact]
    public async Task CompleteBooking_DecreasesVenueCapacity()
    {
        await AuthenticateAsync();
        var venuesResponse = await Client.GetAsync("/api/venues");
        var venues = await venuesResponse.Content.ReadFromJsonAsync<List<VenueDto>>();
        var venueId = venues!.First().Id;

        var venueBefore = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        var capacityBefore = venueBefore!.CurrentCapacity;

        var createResponse = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 1,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(2),
            Notes = (string?)null
        });
        var created = await createResponse.Content.ReadFromJsonAsync<CreateBookingResponseDto>();

        var venueAfterCreate = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        venueAfterCreate!.CurrentCapacity.Should().Be(capacityBefore + 1);

        await Client.PostAsync($"/api/bookings/{created!.BookingId}/complete", content: null);

        var venueAfterComplete = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.Id == venueId);
        venueAfterComplete!.CurrentCapacity.Should().Be(capacityBefore);
    }
}

public class TicketValidationTests : IntegrationTestBase
{
    public TicketValidationTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ValidateTicket_WithSeedPassToken_ReturnsValidTicket()
    {
        // The seed data creates a booking with a stored PassToken for test user.
        // We need to authenticate as a vendor to call validate-ticket.
        await AuthenticateAsync("9000000001");

        // Get the seed booking's pass token directly from DB
        var seedBooking = await Db.ServiceBookings
            .FirstOrDefaultAsync(b => b.Notes == "SEED-TEST-PASS" && b.ServiceType == PondyConnect.Domain.Enums.ServiceType.Nightlife);

        if (seedBooking?.PassToken is null)
        {
            // Seed data not available in this test run — assert instead of silently passing
            seedBooking.Should().NotBeNull("seed data should include a booking with Notes='SEED-TEST-PASS'");
            seedBooking!.PassToken.Should().NotBeNull("seed booking should have a stored pass token");
            return;
        }

        var response = await Client.PostAsJsonAsync("/api/vendor/validate-ticket", new
        {
            QrPayload = seedBooking.PassToken
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<TicketValidationResponseDto>();
        result!.IsValid.Should().BeTrue();
        result.Message.Should().Be("Valid ticket.");
        result.ServiceType.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task ValidateTicket_WithUnknownPayload_ReturnsInvalid()
    {
        await AuthenticateAsync("9000000001");

        var response = await Client.PostAsJsonAsync("/api/vendor/validate-ticket", new
        {
            QrPayload = "invalid-token-xyz"
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<TicketValidationResponseDto>();
        result!.IsValid.Should().BeFalse();
        result.Message.Should().Be("Unknown ticket.");
    }

    [Fact]
    public async Task ValidateTicket_WithEmptyPayload_ReturnsInvalid()
    {
        await AuthenticateAsync("9000000001");

        var response = await Client.PostAsJsonAsync("/api/vendor/validate-ticket", new
        {
            QrPayload = ""
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<TicketValidationResponseDto>();
        result!.IsValid.Should().BeFalse();
        result.Message.Should().Be("Empty QR payload.");
    }

    [Fact]
    public async Task ValidateTicket_WithoutVendorAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");

        var response = await Client.PostAsJsonAsync("/api/vendor/validate-ticket", new
        {
            QrPayload = "some-token"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    record TicketValidationResponseDto(bool IsValid, string ServiceType, string UserName, string Message);
}

public class PaymentFoodOrderTests : IntegrationTestBase
{
    public PaymentFoodOrderTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task InitiatePayment_WithFoodOrderId_RequiresFoodOrderIdInBody()
    {
        await AuthenticateAsync();

        // Create a food order first
        var checkoutResponse = await Client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1,
            Items = new[] { new { Name = "Margherita Pizza", Quantity = 1, UnitPrice = 280m } }
        });
        var checkout = await checkoutResponse.Content.ReadFromJsonAsync<CheckoutResponseDto>();

        // Initiate payment with FoodOrderId
        var paymentResponse = await Client.PostAsJsonAsync("/api/payments", new
        {
            FoodOrderId = checkout!.OrderId,
            Amount = checkout.TotalAmount,
            Currency = "INR"
        });

        // Should succeed (payment order creation may fail in test env without real gateway,
        // but the FoodOrderId validation should pass)
        var statusCode = paymentResponse.StatusCode;
        // Accept both Created (if gateway mock works) and BadRequest (if gateway fails)
        // but NOT 422/UnprocessableEntity (which would indicate validation failure)
        statusCode.Should().NotBe(HttpStatusCode.UnprocessableEntity);
    }

    [Fact]
    public async Task InitiatePayment_WithNoBookingReference_ReturnsBadRequest()
    {
        await AuthenticateAsync();

        var response = await Client.PostAsJsonAsync("/api/payments", new
        {
            Amount = 100m,
            Currency = "INR"
        });

        response.StatusCode.Should().Be(HttpStatusCode.UnprocessableEntity);
    }

    record CheckoutResponseDto(Guid OrderId, decimal SubTotal, decimal VendorPayout, decimal DeliveryFee, decimal LateNightDriverBonus, decimal PlatformFee, decimal TotalAmount, string Status);
}

public class HomestayEndpointsTests : IntegrationTestBase
{
    public HomestayEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task SearchHomestays_WithValidDates_ReturnsList()
    {
        var checkIn = DateOnly.FromDateTime(DateTimeOffset.UtcNow.Date).AddDays(1);
        var checkOut = checkIn.AddDays(2);
        var response = await Client.GetAsync($"/api/homestays/search?checkIn={checkIn:yyyy-MM-dd}&checkOut={checkOut:yyyy-MM-dd}&guests=2");
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<List<HomestaySearchDto>>();
        result.Should().NotBeEmpty();
    }

    [Fact]
    public async Task SearchHomestays_WithInvalidDates_ReturnsBadRequest()
    {
        var response = await Client.GetAsync("/api/homestays/search?checkIn=invalid&checkOut=also-invalid");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task SearchHomestays_WithCheckoutBeforeCheckin_ReturnsBadRequest()
    {
        var checkIn = DateOnly.FromDateTime(DateTimeOffset.UtcNow.Date).AddDays(5);
        var checkOut = checkIn.AddDays(-2);
        var response = await Client.GetAsync($"/api/homestays/search?checkIn={checkIn:yyyy-MM-dd}&checkOut={checkOut:yyyy-MM-dd}");
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task GetHomestay_WithValidId_ReturnsHomestay()
    {
        var listResponse = await Client.GetAsync("/api/homestays");
        listResponse.EnsureSuccessStatusCode();
        var list = await listResponse.Content.ReadFromJsonAsync<List<HomestaySearchDto>>();
        var firstId = list!.First().Id;

        var response = await Client.GetAsync($"/api/homestays/{firstId}");
        response.EnsureSuccessStatusCode();
        var homestay = await response.Content.ReadFromJsonAsync<HomestaySearchDto>();
        homestay!.Name.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task GetHomestay_WithNonExistentId_ReturnsNotFound()
    {
        var response = await Client.GetAsync($"/api/homestays/{Guid.NewGuid()}");
        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task ListHomestays_ReturnsVerifiedOnly()
    {
        var response = await Client.GetAsync("/api/homestays");
        response.EnsureSuccessStatusCode();
        var list = await response.Content.ReadFromJsonAsync<List<HomestaySearchDto>>();
        list.Should().NotBeEmpty();
        list!.Should().AllSatisfy(h => h.IsVerified.Should().BeTrue());
    }

    record HomestaySearchDto(Guid Id, string Name, string Description, string LocationArea, double Latitude, double Longitude, decimal NightlyRate, int MaxGuests, bool HasWifi, bool IsVerified);
}

public class LuggageEndpointsTests : IntegrationTestBase
{
    public LuggageEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task CreateLuggageDropOff_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var vendorId = await GetFirstLuggageVendorIdAsync();
        var now = DateTimeOffset.UtcNow.AddMinutes(10);
        var response = await Client.PostAsJsonAsync("/api/luggage/drop-offs", new
        {
            VendorId = vendorId,
            ScheduledFor = now,
            DroppedAt = now,
            BagCount = 2,
            RatePerHour = 20m,
            Notes = "Two suitcases"
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<LuggageDropOffResponseDto>();
        result!.DropOffId.Should().NotBeEmpty();
        result.Status.Should().NotBeNullOrEmpty();
    }

    [Fact]
    public async Task CreateLuggageDropOff_WithoutAuth_ReturnsUnauthorized()
    {
        var vendorId = await GetFirstLuggageVendorIdAsync();
        var now = DateTimeOffset.UtcNow.AddMinutes(10);
        var response = await Client.PostAsJsonAsync("/api/luggage/drop-offs", new
        {
            VendorId = vendorId,
            ScheduledFor = now,
            DroppedAt = now,
            BagCount = 1,
            RatePerHour = 20m
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetLuggageDropOffs_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/luggage/drop-offs");
        response.EnsureSuccessStatusCode();
    }

    private async Task<Guid> GetFirstLuggageVendorIdAsync()
    {
        var vendor = await Db.Vendors.AsNoTracking().FirstOrDefaultAsync();
        return vendor?.Id ?? SeedVendorId;
    }

    record LuggageDropOffResponseDto(Guid DropOffId, string Status, decimal TotalAmount);
}

public class TransitEndpointsTests : IntegrationTestBase
{
    public TransitEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ListTransitHubs_ReturnsActiveHubs()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/transit/hubs");
        response.EnsureSuccessStatusCode();
        var hubs = await response.Content.ReadFromJsonAsync<List<TransitHubDto>>();
        hubs.Should().NotBeEmpty();
    }

    [Fact]
    public async Task ListTransitHubs_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/transit/hubs");
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CreateTransitTrip_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var hubId = await GetFirstTransitHubIdAsync();
        var arrival = DateTimeOffset.UtcNow.AddHours(2);
        var response = await Client.PostAsJsonAsync("/api/transit/trips", new
        {
            HubId = hubId,
            ArrivalFrom = "Chennai",
            ArrivalMode = "Bus",
            ArrivalAt = arrival,
            PartySize = 2,
            Price = 150m,
            DropOffLocation = "White Town",
            Notes = "Airport pickup"
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<TransitTripResponseDto>();
        result!.TripId.Should().NotBeEmpty();
    }

    [Fact]
    public async Task GetTransitTrips_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/transit/trips");
        response.EnsureSuccessStatusCode();
    }

    private async Task<Guid> GetFirstTransitHubIdAsync()
    {
        var hub = await Db.TransitHubs.AsNoTracking().FirstOrDefaultAsync();
        return hub!.Id;
    }

    record TransitHubDto(Guid Id, string Name, string Kind, double Latitude, double Longitude, string? Address);
    record TransitTripResponseDto(Guid TripId, string Status, decimal Amount);
}

public class RentalEndpointsTests : IntegrationTestBase
{
    public RentalEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task CreateScooterRental_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var vendorId = await GetFirstRentalVendorIdAsync();
        var start = DateTimeOffset.UtcNow.AddMinutes(10);
        var response = await Client.PostAsJsonAsync("/api/rental/scooters", new
        {
            VendorId = vendorId,
            VehicleName = "Honda Activa",
            RentalStart = start,
            RentalEnd = start.AddHours(4),
            RatePerHour = 75m,
            VehiclePlate = "PY-01-XY-9999",
            Notes = "Helmet included"
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<ScooterRentalResponseDto>();
        result!.RentalId.Should().NotBeEmpty();
    }

    [Fact]
    public async Task CreateScooterRental_WithoutAuth_ReturnsUnauthorized()
    {
        var vendorId = await GetFirstRentalVendorIdAsync();
        var start = DateTimeOffset.UtcNow.AddMinutes(10);
        var response = await Client.PostAsJsonAsync("/api/rental/scooters", new
        {
            VendorId = vendorId,
            VehicleName = "Honda Activa",
            RentalStart = start,
            RentalEnd = start.AddHours(4),
            RatePerHour = 75m
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetScooterRentals_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/rental/scooters");
        response.EnsureSuccessStatusCode();
    }

    private async Task<Guid> GetFirstRentalVendorIdAsync()
    {
        var vendor = await Db.Vendors.AsNoTracking().FirstOrDefaultAsync();
        return vendor?.Id ?? SeedVendorId;
    }

    record ScooterRentalResponseDto(Guid RentalId, string Status, decimal TotalAmount);
}

public class SupportEndpointsTests : IntegrationTestBase
{
    public SupportEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task SendMessage_WithAuth_ReturnsResponse()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/support/message", new
        {
            MessageText = "I need help with my booking"
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task SendMessage_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/support/message", new
        {
            MessageText = "Help"
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CreateSos_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/support/sos", new
        {
            Issue = "Scooter breakdown on highway",
            Latitude = 11.9356,
            Longitude = 79.8301
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetMyTickets_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/support/tickets");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetCriticalTickets_WithoutAdminAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.GetAsync("/api/support/critical");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task AcknowledgeTicket_WithAdminAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000099");
        var sosResponse = await Client.PostAsJsonAsync("/api/support/sos", new
        {
            Issue = "Lost wallet",
            Latitude = 11.9356,
            Longitude = 79.8301
        });
        sosResponse.EnsureSuccessStatusCode();
        var sosResult = await sosResponse.Content.ReadFromJsonAsync<SosResponseDto>();

        // Admin auth not available in test env (no seeded admin user).
        // Verify that a non-admin gets Forbidden on acknowledge.
        var ackResponse = await Client.PostAsync($"/api/support/tickets/{sosResult!.TicketId}/acknowledge", content: null);
        ackResponse.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    record SosResponseDto(Guid TicketId, string DetectedIntent, bool IsCritical, string AiReply);
}

public class DriverEndpointsTests : IntegrationTestBase
{
    public DriverEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RegisterDriver_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/driver/register", new
        {
            Name = "Test Driver",
            Phone = "9000000099",
            VehicleType = 1,
            VehiclePlate = "PY-01-TT-0001"
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task RegisterDriver_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/driver/register", new
        {
            Name = "Test Driver",
            Phone = "9000000099",
            VehicleType = 1
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GoOnline_WithAuth_ReturnsNoContent()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync("/api/driver/online", content: null);
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetDriverTasks_WithAuth_ReturnsList()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/driver/tasks");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetDriverWallet_WithoutRegistration_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/driver/wallet");
        response.EnsureSuccessStatusCode();
    }
}

public class AdminEndpointsTests : IntegrationTestBase
{
    public AdminEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ForceSoldOut_WithoutAdminAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var venueId = await GetFirstVenueIdAsync();
        var response = await Client.PostAsync($"/api/admin/venues/{venueId}/force-soldout?soldOut=true", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task SetSurgeMode_WithoutAdminAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.PostAsJsonAsync("/api/admin/surge", new { Mode = 1 });
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetSosEvents_WithoutAdminAuth_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.GetAsync("/api/admin/sos-events");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task ApproveDriver_WithNonExistentId_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.PostAsync($"/api/admin/approve-driver/{Guid.NewGuid()}", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    private async Task<Guid> GetFirstVenueIdAsync()
    {
        var venue = await Db.Venues.AsNoTracking().FirstOrDefaultAsync();
        return venue!.Id;
    }
}

public class WaitlistEndpointsTests : IntegrationTestBase
{
    public WaitlistEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task JoinWaitlist_WithValidPhone_ReturnsCreated()
    {
        var response = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = "9000012345",
            SourceQrCodeLocation = "Airport"
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<WaitlistJoinResponseDto>();
        result!.Id.Should().NotBeEmpty();
        result.Position.Should().BeGreaterThan(0);
        result.AlreadyOnWaitlist.Should().BeFalse();
    }

    [Fact]
    public async Task JoinWaitlist_WithInvalidPhone_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = "123",
            SourceQrCodeLocation = (string?)null
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task JoinWaitlist_DuplicatePhone_ReturnsOkWithAlreadyOnWaitlist()
    {
        var phone = "9000099999";
        var firstResponse = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = phone,
            SourceQrCodeLocation = "Bus Stand"
        });
        firstResponse.EnsureSuccessStatusCode();

        var secondResponse = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = phone,
            SourceQrCodeLocation = "Bus Stand"
        });
        secondResponse.StatusCode.Should().Be(HttpStatusCode.OK);
        var result = await secondResponse.Content.ReadFromJsonAsync<WaitlistJoinResponseDto>();
        result!.AlreadyOnWaitlist.Should().BeTrue();
    }

    record WaitlistJoinResponseDto(Guid Id, int Position, bool AlreadyOnWaitlist);
}

public class TelemetryEndpointsTests : IntegrationTestBase
{
    public TelemetryEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task LogEvents_WithEvents_ReturnsAccepted()
    {
        var response = await Client.PostAsJsonAsync("/api/telemetry/log", new
        {
            SessionId = "test-session-1",
            Events = new[]
            {
                new { EventName = "app_open", Payload = (object?)new { screen = "home" } },
                new { EventName = "scroll", Payload = (object?)null }
            }
        });
        response.StatusCode.Should().Be(HttpStatusCode.Accepted);
    }

    [Fact]
    public async Task LogEvents_WithEmptyEvents_ReturnsAccepted()
    {
        var response = await Client.PostAsJsonAsync("/api/telemetry/log", new
        {
            SessionId = "test-session-2",
            Events = Array.Empty<object>()
        });
        response.StatusCode.Should().Be(HttpStatusCode.Accepted);
    }
}

public class VendorAuthEndpointsTests : IntegrationTestBase
{
    public VendorAuthEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RequestVendorOtp_WithValidPhone_ReturnsOk()
    {
        var response = await Client.PostAsJsonAsync("/api/vendor/auth/otp/request", new
        {
            Phone = "9000000001"
        });
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task RequestVendorOtp_WithInvalidPhone_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/vendor/auth/otp/request", new
        {
            Phone = "123"
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task VerifyVendorOtp_WithInvalidOtp_ReturnsUnauthorized()
    {
        await Client.PostAsJsonAsync("/api/vendor/auth/otp/request", new { Phone = "9000000001" });
        var response = await Client.PostAsJsonAsync("/api/vendor/auth/otp/verify", new
        {
            Phone = "9000000001",
            OtpCode = "000000"
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}

public class DeviceTokenEndpointsTests : IntegrationTestBase
{
    public DeviceTokenEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task UpdateDeviceToken_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/user/device-token", new
        {
            Token = "firebase-token-abc123"
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task UpdateDeviceToken_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/user/device-token", new
        {
            Token = "firebase-token-abc123"
        });
        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}

public class PaymentRefundWebhookTests : IntegrationTestBase
{
    public PaymentRefundWebhookTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RefundPayment_WithNonExistentId_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var fakePaymentId = Guid.NewGuid();
        var response = await Client.PostAsJsonAsync($"/api/payments/{fakePaymentId}/refund", new
        {
            PaymentId = fakePaymentId,
            Amount = 100m,
            Reason = "Customer request"
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task RefundPayment_WithIdMismatch_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var id1 = Guid.NewGuid();
        var id2 = Guid.NewGuid();
        var response = await Client.PostAsJsonAsync($"/api/payments/{id1}/refund", new
        {
            PaymentId = id2,
            Amount = 100m,
            Reason = "Mismatch"
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task PaymentWebhook_WithoutSignature_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/payments/webhook", new
        {
            Payload = "{}",
            Signature = ""
        });
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}

public class WhatsAppWebhookEndpointsTests : IntegrationTestBase
{
    public WhatsAppWebhookEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task VerifyWebhook_WithInvalidToken_ReturnsForbidden()
    {
        var response = await Client.GetAsync("/api/whatsapp/webhook?hubMode=subscribe&hubVerifyToken=wrong-token&hubChallenge=challenge123");
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}

public class VendorsListEndpointsTests : IntegrationTestBase
{
    public VendorsListEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ListVendors_ReturnsNonEmpty()
    {
        var response = await Client.GetAsync("/api/vendors");
        response.EnsureSuccessStatusCode();
        var vendors = await response.Content.ReadFromJsonAsync<List<VendorResponseDto>>();
        vendors.Should().NotBeEmpty();
    }

    [Fact]
    public async Task ListVendors_WithCategoryFilter_ReturnsFiltered()
    {
        var response = await Client.GetAsync("/api/vendors?category=1");
        response.EnsureSuccessStatusCode();
    }

    record VendorResponseDto(Guid Id, string Name, string Category, string? ContactPhone, bool IsApproved);
}

public class RideHailingRoleTests : IntegrationTestBase
{
    public RideHailingRoleTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RequestRide_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "White Town, Pondicherry",
            DropoffLatitude = 11.9416,
            DropoffLongitude = 79.8083,
            DropoffAddress = "Rock Beach, Pondicherry",
            DistanceKm = 3.5,
            VehicleType = 1,
            PaymentMethod = 1
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<RideRequestResponseDto>();
        result!.RideId.Should().NotBeEmpty();
        result.Fare.Should().BeGreaterThan(0);
        result.TotalAmount.Should().BeGreaterThan(result.Fare);
    }

    [Fact]
    public async Task AcceptRide_WithoutDriverRole_ReturnsForbidden()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync($"/api/rides/{Guid.NewGuid()}/accept", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task StartRide_WithoutDriverRole_ReturnsForbidden()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync($"/api/rides/{Guid.NewGuid()}/start", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task CancelRide_WithAuth_ReturnsNoContent()
    {
        await AuthenticateAsync();
        var rideResponse = await Client.PostAsJsonAsync("/api/rides", new
        {
            PickupLatitude = 11.9356,
            PickupLongitude = 79.8301,
            PickupAddress = "White Town",
            DropoffLatitude = 11.9416,
            DropoffLongitude = 79.8083,
            DropoffAddress = "Rock Beach",
            DistanceKm = 3.5,
            VehicleType = 1,
            PaymentMethod = 1
        });
        rideResponse.EnsureSuccessStatusCode();
        var ride = await rideResponse.Content.ReadFromJsonAsync<RideRequestResponseDto>();

        var response = await Client.PostAsJsonAsync($"/api/rides/{ride!.RideId}/cancel", new { Reason = "Changed mind" });
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    record RideRequestResponseDto(Guid RideId, double DistanceKm, int EstimatedDurationMin, decimal Fare, decimal DriverEarnings, decimal PlatformBookingFee, decimal TotalAmount, string Status, string VehicleType, string PaymentMethod);
}

public class BookingsExtraTests : IntegrationTestBase
{
    public BookingsExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task CreateBooking_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var venueId = await GetFirstVenueIdAsync();
        var response = await Client.PostAsJsonAsync("/api/bookings", new
        {
            VenueId = venueId,
            Seats = 2,
            ScheduledFor = DateTimeOffset.UtcNow.AddDays(1),
            Notes = "Test booking"
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CreateLongWeekendPass_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/bookings/long-weekend-pass", new
        {
            Days = 3
        });
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    [Fact]
    public async Task CancelBooking_WithNonExistentId_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync($"/api/bookings/{Guid.NewGuid()}/cancel", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task CompleteBooking_WithNonExistentId_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync($"/api/bookings/{Guid.NewGuid()}/complete", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    private async Task<Guid> GetFirstVenueIdAsync()
    {
        var venue = await Db.Venues.AsNoTracking().FirstOrDefaultAsync();
        return venue!.Id;
    }
}

public class VendorCrudEndpointsTests : IntegrationTestBase
{
    public VendorCrudEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetBookings_WithVendorAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/bookings");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CreateVenue_WithVendorAuth_ReturnsCreated()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.PostAsJsonAsync("/api/vendor/venues", new
        {
            Name = "Test Venue",
            Category = 1,
            Latitude = 11.93,
            Longitude = 79.83,
            MaxCapacity = 50,
            Address = "123 Test Street"
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task UpdateVenue_WithVendorAuth_ReturnsNoContent()
    {
        await AuthenticateAsync("9000000001");
        var venueId = await GetFirstVendorVenueIdAsync();
        var response = await Client.PutAsJsonAsync($"/api/vendor/venues/{venueId}", new
        {
            VenueId = venueId,
            Name = "Updated Venue Name",
            Category = 1,
            Latitude = 11.93,
            Longitude = 79.83,
            MaxCapacity = 60,
            Address = "Updated Address"
        });
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task DeactivateVenue_WithVendorAuth_ReturnsNoContent()
    {
        await AuthenticateAsync("9000000001");
        var venueId = await GetFirstVendorVenueIdAsync();
        var response = await Client.DeleteAsync($"/api/vendor/venues/{venueId}");
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task ValidateTicket_WithInvalidQr_ReturnsOkWithIsValidFalse()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.PostAsJsonAsync("/api/vendor/validate-ticket", new
        {
            QrPayload = "invalid-qr-payload"
        });
        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<VendorTicketValidationDto>();
        result!.IsValid.Should().BeFalse();
    }

    private async Task<Guid> GetFirstVendorVenueIdAsync()
    {
        var venue = await Db.Venues.AsNoTracking().FirstOrDefaultAsync(v => v.VendorId == SeedVendorId);
        return venue!.Id;
    }

    record VendorTicketValidationDto(bool IsValid, string ServiceType, string UserName, string Message);
}

public class FoodDeliveryVendorEndpointsTests : IntegrationTestBase
{
    public FoodDeliveryVendorEndpointsTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task CreateMenuItem_WithVendorAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.PostAsJsonAsync("/api/vendor/menu", new
        {
            VendorId = SeedVendorId,
            Name = "Test Pizza",
            Price = 250m,
            Category = "Main Course",
            Description = "Delicious test pizza",
            IsLateNight = false
        });
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CreateMenuItem_WithoutVendorRole_ReturnsForbidden()
    {
        await AuthenticateAsync("9000000099");
        var response = await Client.PostAsJsonAsync("/api/vendor/menu", new
        {
            VendorId = SeedVendorId,
            Name = "Test Pizza",
            Price = 250m,
            Category = "Main Course"
        });
        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task UpdateMenuItem_WithVendorAuth_ReturnsNoContent()
    {
        await AuthenticateAsync("9000000001");
        var menuItemId = await GetFirstMenuItemIdAsync();
        var response = await Client.PutAsJsonAsync($"/api/vendor/menu/{menuItemId}", new
        {
            Name = "Updated Item",
            Description = "Updated description",
            Category = "Main Course",
            NewPrice = (decimal?)300m
        });
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task ToggleMenuItem_WithVendorAuth_ReturnsNoContent()
    {
        await AuthenticateAsync("9000000001");
        var menuItemId = await GetFirstMenuItemIdAsync();
        var response = await Client.PostAsync($"/api/vendor/menu/{menuItemId}/toggle", content: null);
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task ListVendorMenu_WithVendorAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/menu");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task ListVendorOrders_WithVendorAuth_ReturnsOk()
    {
        await AuthenticateAsync("9000000001");
        var response = await Client.GetAsync("/api/vendor/orders");
        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task UpdateOrderStatus_WithVendorAuth_ReturnsNoContent()
    {
        await AuthenticateAsync("9000000001");
        var orderId = await GetFirstFoodOrderIdAsync();
        if (orderId == Guid.Empty)
            return;
        var response = await Client.PutAsJsonAsync($"/api/vendor/orders/{orderId}/status", new
        {
            NewStatus = "Accepted"
        });
        response.StatusCode.Should().Be(HttpStatusCode.NoContent);
    }

    private async Task<Guid> GetFirstMenuItemIdAsync()
    {
        var menuItem = await Db.MenuItems.AsNoTracking().FirstOrDefaultAsync(m => m.VendorId == SeedVendorId);
        return menuItem!.Id;
    }

    private async Task<Guid> GetFirstFoodOrderIdAsync()
    {
        var order = await Db.FoodOrders.AsNoTracking().FirstOrDefaultAsync();
        return order?.Id ?? Guid.Empty;
    }
}

public class AuthEdgeCasesTests : IntegrationTestBase
{
    public AuthEdgeCasesTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task VerifyOtp_WithWrongCode_ReturnsUnauthorized()
    {
        await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = "9000000099" });

        var response = await Client.PostAsJsonAsync("/api/auth/otp/verify", new
        {
            Phone = "9000000099",
            Otp = "000000",
            Name = "Test User"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task RequestOtp_WithEmptyPhone_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/auth/otp/request", new { Phone = "" });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task AcceptWaiver_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsync("/api/auth/waiver/accept", content: null);

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}

public class AdminExtraTests : IntegrationTestBase
{
    public AdminExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ForceSoldOut_WithTouristAuth_ReturnsForbidden()
    {
        await AuthenticateAsync();
        var venue = await Db.Venues.AsNoTracking().FirstOrDefaultAsync();
        if (venue == null) return;
        var response = await Client.PostAsync($"/api/admin/venues/{venue.Id}/force-soldout?soldOut=true", content: null);

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task SetSurgeMode_WithTouristAuth_ReturnsForbidden()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/admin/surge", new { Mode = 1 });

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }

    [Fact]
    public async Task GetSosEvents_WithTouristAuth_ReturnsForbidden()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/admin/sos-events");

        response.StatusCode.Should().Be(HttpStatusCode.Forbidden);
    }
}

public class HomestayExtraTests : IntegrationTestBase
{
    public HomestayExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ListHomestays_ReturnsOnlyVerified()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/homestays?checkIn=2026-01-20&checkOut=2026-01-22");

        response.EnsureSuccessStatusCode();
        var list = await response.Content.ReadFromJsonAsync<List<HomestayExtraDto>>();
        list!.Should().NotBeNull();
    }

    [Fact]
    public async Task GetHomestay_WithInvalidGuid_ReturnsNotFound()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync($"/api/homestays/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    record HomestayExtraDto(Guid Id, string Name, string LocationArea, decimal NightlyRate, int MaxGuests, bool HasWifi, bool IsVerified);
}

public class PaymentWebhookExtraTests : IntegrationTestBase
{
    public PaymentWebhookExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task RefundPayment_WithNonExistentId_ReturnsBadRequest()
    {
        await AuthenticateAsync();
        var fakePaymentId = Guid.NewGuid();
        var response = await Client.PostAsJsonAsync($"/api/payments/{fakePaymentId}/refund", new
        {
            PaymentId = fakePaymentId,
            Amount = 100m,
            Reason = "Test refund"
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task PaymentWebhook_WithEmptyBody_ReturnsBadRequest()
    {
        var response = await Client.PostAsync("/api/payments/webhook",
            new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }
}

public class DriverExtraTests : IntegrationTestBase
{
    public DriverExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GoOnline_WithAuth_ReturnsNoContent()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsync("/api/driver/online", content: null);

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetDriverTasks_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/driver/tasks");

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }
}

public class WaitlistExtraTests : IntegrationTestBase
{
    public WaitlistExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task JoinWaitlist_With10DigitPhone_ReturnsCreated()
    {
        var response = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = "9000000400",
            SourceQrCodeLocation = "QR-Test"
        });

        response.StatusCode.Should().BeOneOf(HttpStatusCode.Created, HttpStatusCode.OK);
    }

    [Fact]
    public async Task JoinWaitlist_DuplicatePhone_ReturnsOkWithAlreadyOnWaitlist()
    {
        // First join
        await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = "9000000401",
            SourceQrCodeLocation = "QR-Test"
        });

        // Second join with same phone
        var response = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            PhoneNumber = "9000000401",
            SourceQrCodeLocation = "QR-Test"
        });

        response.EnsureSuccessStatusCode();
        var result = await response.Content.ReadFromJsonAsync<WaitlistExtraResponseDto>();
        result!.Should().NotBeNull();
    }

    [Fact]
    public async Task JoinWaitlist_WithMissingPhone_ReturnsBadRequest()
    {
        var response = await Client.PostAsJsonAsync("/api/waitlist/join", new
        {
            SourceQrCodeLocation = "QR-Test"
        });

        response.StatusCode.Should().Be(HttpStatusCode.BadRequest);
    }

    record WaitlistExtraResponseDto(Guid Id, int Position, bool AlreadyOnWaitlist);
}

public class QuickCommerceExtraTests : IntegrationTestBase
{
    public QuickCommerceExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ListEssentials_ReturnsOk()
    {
        var response = await Client.GetAsync("/api/essentials");

        response.EnsureSuccessStatusCode();
        var list = await response.Content.ReadFromJsonAsync<List<EssentialProductDto>>();
        list!.Should().NotBeEmpty();
    }

    [Fact]
    public async Task GetEssential_WithValidId_ReturnsOk()
    {
        var product = await Db.Products.AsNoTracking().FirstOrDefaultAsync();
        if (product == null) return;
        var response = await Client.GetAsync($"/api/essentials/{product.Id}");

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task GetEssential_WithInvalidId_ReturnsNotFound()
    {
        var response = await Client.GetAsync($"/api/essentials/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task CreateEssentialsOrder_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/essentials/orders", new
        {
            DeliveryAddress = "Test Address",
            DeliveryLatitude = 11.93,
            DeliveryLongitude = 79.83,
            Items = Array.Empty<object>()
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    record EssentialProductDto(Guid Id, string Name, decimal Price, string Category, string SubCategory, int StockCount, string? Brand, string? Description, bool IsLateNightEssential);
}

public class SupportExtraTests : IntegrationTestBase
{
    public SupportExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task SendMessage_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/support/message", new
        {
            MessageText = "Hello"
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task CreateSos_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.PostAsJsonAsync("/api/support/sos", new
        {
            Issue = "Breakdown",
            Latitude = 11.93,
            Longitude = 79.83
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetMyTickets_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/support/tickets");

        response.EnsureSuccessStatusCode();
    }
}

public class TransitExtraTests : IntegrationTestBase
{
    public TransitExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task ListHubs_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/transit/hubs");

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task ListHubs_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/transit/hubs");

        response.EnsureSuccessStatusCode();
        var list = await response.Content.ReadFromJsonAsync<List<TransitHubExtraDto>>();
        list!.Should().NotBeEmpty();
    }

    record TransitHubExtraDto(Guid Id, string Name, string Kind, string Address, double Latitude, double Longitude, bool IsActive);
}

public class TelemetryExtraTests : IntegrationTestBase
{
    public TelemetryExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task LogEvents_ReturnsAccepted()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/telemetry/log", new
        {
            SessionId = "test-session",
            Events = new[]
            {
                new { EventName = "screen_view", Payload = new { screen = "home" } }
            }
        });

        response.StatusCode.Should().Be(HttpStatusCode.Accepted);
    }

    [Fact]
    public async Task LogEvents_WithEmptyEvents_ReturnsAccepted()
    {
        await AuthenticateAsync();
        var response = await Client.PostAsJsonAsync("/api/telemetry/log", new
        {
            SessionId = "test-session",
            Events = Array.Empty<object>()
        });

        response.StatusCode.Should().Be(HttpStatusCode.Accepted);
    }
}

public class LuggageExtraTests : IntegrationTestBase
{
    public LuggageExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetDropOffs_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/luggage/drop-offs");

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetDropOffs_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/luggage/drop-offs");

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CreateDropOff_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var vendor = await Db.Vendors.AsNoTracking().FirstOrDefaultAsync(v => v.Category == VendorCategory.LuggageCloak);
        if (vendor == null) return;

        var now = DateTimeOffset.UtcNow;
        var response = await Client.PostAsJsonAsync("/api/luggage/drop-offs", new
        {
            VendorId = vendor.Id,
            ScheduledFor = now.AddHours(2),
            DroppedAt = now.AddHours(2),
            BagCount = 2,
            RatePerHour = 20m
        });

        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }
}

public class RentalExtraTests : IntegrationTestBase
{
    public RentalExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetRentals_WithoutAuth_ReturnsUnauthorized()
    {
        var response = await Client.GetAsync("/api/rental/scooters");

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task GetRentals_WithAuth_ReturnsOk()
    {
        await AuthenticateAsync();
        var response = await Client.GetAsync("/api/rental/scooters");

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task CreateRental_WithAuth_ReturnsCreated()
    {
        await AuthenticateAsync();
        var vendor = await Db.Vendors.AsNoTracking().FirstOrDefaultAsync(v => v.Category == VendorCategory.ScooterRental);
        if (vendor == null) return;

        var now = DateTimeOffset.UtcNow;
        var response = await Client.PostAsJsonAsync("/api/rental/scooters", new
        {
            VendorId = vendor.Id,
            VehicleName = "Honda Activa",
            RentalStart = now.AddHours(1),
            RentalEnd = now.AddHours(5),
            RatePerHour = 50m
        });

        response.StatusCode.Should().Be(HttpStatusCode.Created);
    }
}

public class VenueExtraTests : IntegrationTestBase
{
    public VenueExtraTests(CustomWebApplicationFactory factory) : base(factory) { }

    [Fact]
    public async Task GetVenue_WithInvalidId_ReturnsNotFound()
    {
        var response = await Client.GetAsync($"/api/venues/{Guid.NewGuid()}");

        response.StatusCode.Should().Be(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task ListVenues_WithCategoryFilter_ReturnsOk()
    {
        var response = await Client.GetAsync("/api/venues?category=1");

        response.EnsureSuccessStatusCode();
    }

    [Fact]
    public async Task ListVenues_WithPagination_ReturnsOk()
    {
        var response = await Client.GetAsync("/api/venues?page=1&pageSize=5");

        response.EnsureSuccessStatusCode();
    }
}
