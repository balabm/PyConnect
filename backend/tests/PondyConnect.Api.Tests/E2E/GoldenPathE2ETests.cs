using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Infrastructure.Persistence;

// Alias to avoid ambiguity with Domain.Enums
using DispatchTaskStatus = PondyConnect.Domain.Enums.DispatchTaskStatus;

namespace PondyConnect.Api.Tests.E2E;

/// <summary>
/// Golden path E2E test: consumer creates a food order, vendor advances it
/// through KDS stages to OutForDelivery, a DispatchTask is created, a driver
/// accepts and progresses through all delivery phases to Completed.
///
/// Uses a real PostgreSQL test container (requires Docker Desktop).
/// </summary>
public class GoldenPathE2ETests : IClassFixture<PostgresWebApplicationFactory>
{
    private readonly PostgresWebApplicationFactory _factory;
    private readonly HttpClient _client;
    private readonly IServiceScope _scope;
    private readonly ApplicationDbContext _db;

    private static readonly Guid SeedVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    public GoldenPathE2ETests(PostgresWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        _scope = factory.Services.CreateScope();
        _db = _scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    }

    /// <summary>
    /// Retries a POST request on 429 Too Many Requests.
    /// </summary>
    private async Task<HttpResponseMessage> PostWithRetryAsync(string url, object payload)
    {
        for (int attempt = 0; attempt < 5; attempt++)
        {
            var response = await _client.PostAsJsonAsync(url, payload);
            if (response.StatusCode != HttpStatusCode.TooManyRequests)
                return response;
            await Task.Delay(2000 * (attempt + 1));
        }
        return await _client.PostAsJsonAsync(url, payload);
    }

    /// <summary>
    /// Authenticates via OTP and returns the access token. Uses the test OTP
    /// service which exposes codes in plaintext.
    /// </summary>
    private async Task<(string Token, Guid UserId)> AuthenticateAsync(string phone)
    {
        // Request OTP
        var otpResponse = await PostWithRetryAsync("/api/auth/otp/request", new { Phone = phone, Name = "E2E User" });
        otpResponse.EnsureSuccessStatusCode();

        // Extract OTP from the in-memory OTP service
        var otpService = (TestOtpService)_scope.ServiceProvider.GetRequiredService<IOtpService>();
        var otp = await otpService.GetCodeForTestAsync(phone);

        // Verify OTP
        var verifyResponse = await PostWithRetryAsync("/api/auth/otp/verify", new
        {
            Phone = phone,
            Otp = otp,
            Name = "E2E Test User"
        });
        verifyResponse.EnsureSuccessStatusCode();

        var result = await verifyResponse.Content.ReadFromJsonAsync<AuthResponseDto>();
        _client.DefaultRequestHeaders.Authorization = new("Bearer", result!.AccessToken);

        // Accept liability waiver so ride/rental endpoints work
        await _client.PostAsync("/api/auth/waiver/accept", content: null);

        return (result.AccessToken, result.UserId);
    }

    /// <summary>
    /// Authenticates as a vendor using the vendor-specific OTP endpoints.
    /// </summary>
    private async Task<string> AuthenticateAsVendorAsync(string phone)
    {
        var otpResponse = await PostWithRetryAsync("/api/vendor/auth/otp/request", new { Phone = phone });
        otpResponse.EnsureSuccessStatusCode();

        var otpService = (TestOtpService)_scope.ServiceProvider.GetRequiredService<IOtpService>();
        var otp = await otpService.GetCodeForTestAsync(phone);

        var verifyResponse = await PostWithRetryAsync("/api/vendor/auth/otp/verify", new
        {
            Phone = phone,
            OtpCode = otp
        });
        verifyResponse.EnsureSuccessStatusCode();

        var result = await verifyResponse.Content.ReadFromJsonAsync<VendorAuthResponseDto>();
        _client.DefaultRequestHeaders.Authorization = new("Bearer", result!.AccessToken);

        return result.AccessToken;
    }

    [Fact]
    public async Task FullDispatchFlow_ConsumerToDriverCompletion()
    {
        // ── Step 1: Consumer authenticates ──
        var (consumerToken, consumerId) = await AuthenticateAsync("9000000099");
        consumerToken.Should().NotBeNullOrEmpty();

        // ── Step 2: Consumer creates a food order with Cash on Delivery ──
        var checkoutResponse = await _client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland, White Town",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1, // Cash
            Items = new[]
            {
                new { Name = "Woodfired Margherita", Quantity = 2, UnitPrice = 450m }
            }
        });
        checkoutResponse.EnsureSuccessStatusCode();
        var checkout = await checkoutResponse.Content.ReadFromJsonAsync<CheckoutResponseDto>();
        checkout!.OrderId.Should().NotBeEmpty();
        checkout.Status.Should().Be("Placed");
        checkout.SubTotal.Should().Be(900m);

        // ── Step 3: Vendor authenticates (Fuoco Pizzeria seed vendor) ──
        await AuthenticateAsVendorAsync("9000000001");

        // ── Step 4: Vendor advances order through KDS stages ──
        // Placed → Accepted
        var acceptResponse = await _client.PutAsJsonAsync(
            $"/api/vendor/orders/{checkout.OrderId}/status",
            new { NewStatus = "Accepted" });
        acceptResponse.EnsureSuccessStatusCode();

        // Accepted → Preparing
        var prepareResponse = await _client.PutAsJsonAsync(
            $"/api/vendor/orders/{checkout.OrderId}/status",
            new { NewStatus = "Preparing" });
        prepareResponse.EnsureSuccessStatusCode();

        // Preparing → OutForDelivery (this triggers DispatchTask creation + SignalR offers)
        var dispatchResponse = await _client.PutAsJsonAsync(
            $"/api/vendor/orders/{checkout.OrderId}/status",
            new { NewStatus = "OutForDelivery" });
        dispatchResponse.EnsureSuccessStatusCode();

        // ── Step 5: Verify DispatchTask was created in the database ──
        var dispatchTask = await _db.DispatchTasks
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.SourceEntityId == checkout.OrderId
                && t.TaskType == DispatchTaskType.FoodDelivery);
        dispatchTask.Should().NotBeNull("a DispatchTask should be created when the food order transitions to OutForDelivery");
        dispatchTask!.Status.Should().Be(DispatchTaskStatus.Available);
        dispatchTask.DriverEarnings.Should().BeGreaterThan(0);

        // ── Step 6: Driver authenticates (seed driver Suresh Kumar) ──
        await AuthenticateAsync("9000000050");

        // ── Step 7: Driver updates location to register in DriverLocationStore ──
        var locationResponse = await _client.PostAsJsonAsync("/api/driver/location", new
        {
            Latitude = 11.9390,
            Longitude = 79.8350
        });
        locationResponse.EnsureSuccessStatusCode();

        // ── Step 8: Driver fetches available tasks ──
        var tasksResponse = await _client.GetAsync("/api/driver/tasks");
        tasksResponse.EnsureSuccessStatusCode();
        var tasks = await tasksResponse.Content.ReadFromJsonAsync<List<DispatchTaskDto>>();
        tasks.Should().NotBeEmpty("the food delivery task should be visible to the driver");

        var foodTask = tasks!.FirstOrDefault(t => t.Id == dispatchTask.Id);
        foodTask.Should().NotBeNull("the food delivery DispatchTask should be in the available tasks list");
        foodTask!.Status.Should().Be("Available");
        foodTask.TaskType.Should().Be("FoodDelivery");

        // ── Step 9: Driver accepts the task ──
        var acceptTaskResponse = await _client.PostAsync(
            $"/api/driver/tasks/{dispatchTask.Id}/accept", content: null);
        acceptTaskResponse.EnsureSuccessStatusCode();
        var acceptedTask = await acceptTaskResponse.Content.ReadFromJsonAsync<DispatchTaskDto>();
        acceptedTask!.Status.Should().Be("Assigned");
        acceptedTask.DriverId.Should().NotBeNull();

        // ── Step 10: Driver marks arrived at store ──
        var arrivedResponse = await _client.PostAsync(
            $"/api/driver/tasks/{dispatchTask.Id}/arrived-at-store", content: null);
        arrivedResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // Verify DB state
        var taskAfterArrived = await _db.DispatchTasks
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == dispatchTask.Id);
        taskAfterArrived!.Status.Should().Be(DispatchTaskStatus.ArrivedAtStore);

        // ── Step 11: Driver marks out for delivery ──
        var outForDeliveryResponse = await _client.PostAsync(
            $"/api/driver/tasks/{dispatchTask.Id}/out-for-delivery", content: null);
        outForDeliveryResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        var taskAfterOutForDelivery = await _db.DispatchTasks
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == dispatchTask.Id);
        taskAfterOutForDelivery!.Status.Should().Be(DispatchTaskStatus.OutForDelivery);

        // ── Step 12: Driver completes the task ──
        var completeResponse = await _client.PostAsync(
            $"/api/driver/tasks/{dispatchTask.Id}/complete", content: null);
        completeResponse.StatusCode.Should().Be(HttpStatusCode.NoContent);

        // ── Step 13: Verify DispatchTask is Completed in DB ──
        var taskAfterComplete = await _db.DispatchTasks
            .AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == dispatchTask.Id);
        taskAfterComplete!.Status.Should().Be(DispatchTaskStatus.Completed);
    }

    // ── DTOs ──

    private sealed record AuthResponseDto(
        string AccessToken,
        Guid UserId,
        string Name,
        string Phone,
        string Role,
        bool IsProMember,
        bool IsVerifiedLocal);

    private sealed record CheckoutResponseDto(
        Guid OrderId,
        decimal VendorPayout,
        decimal SubTotal,
        decimal DeliveryFee,
        decimal LateNightDriverBonus,
        decimal PlatformFee,
        decimal TotalAmount,
        string Status);

    private sealed record DispatchTaskDto(
        Guid Id,
        string TaskType,
        string PickupAddress,
        string DropoffAddress,
        decimal DriverEarnings,
        string Status,
        Guid? DriverId);

    private sealed record VendorAuthResponseDto(
        string AccessToken,
        Guid VendorId,
        string VendorName,
        string Category,
        string Phone,
        string Status);
}
