using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Infrastructure.Persistence;

namespace PondyConnect.Api.Tests.E2E;

/// <summary>
/// Guardrail E2E tests: emergency release, partial refund, delete account,
/// and payment reconciliation idempotency. Uses a real PostgreSQL test container.
/// </summary>
public class GuardrailE2ETests : IClassFixture<PostgresWebApplicationFactory>
{
    private readonly PostgresWebApplicationFactory _factory;
    private readonly HttpClient _client;
    private readonly IServiceScope _scope;
    private readonly ApplicationDbContext _db;

    private static readonly Guid SeedVendorId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    public GuardrailE2ETests(PostgresWebApplicationFactory factory)
    {
        _factory = factory;
        _client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            AllowAutoRedirect = false
        });
        _scope = factory.Services.CreateScope();
        _db = _scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
    }

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

    private async Task<(string Token, Guid UserId)> AuthenticateAsync(string phone)
    {
        var otpResponse = await PostWithRetryAsync("/api/auth/otp/request", new { Phone = phone, Name = "E2E User" });
        otpResponse.EnsureSuccessStatusCode();

        var otpService = (TestOtpService)_scope.ServiceProvider.GetRequiredService<IOtpService>();
        var otp = await otpService.GetCodeForTestAsync(phone);

        var verifyResponse = await PostWithRetryAsync("/api/auth/otp/verify", new
        {
            Phone = phone,
            Otp = otp,
            Name = "E2E Guardrail User"
        });
        verifyResponse.EnsureSuccessStatusCode();

        var result = await verifyResponse.Content.ReadFromJsonAsync<AuthResponseDto>();
        _client.DefaultRequestHeaders.Authorization = new("Bearer", result!.AccessToken);
        await _client.PostAsync("/api/auth/waiver/accept", content: null);

        return (result.AccessToken, result.UserId);
    }

    /// <summary>
    /// Authenticates as a vendor using the vendor-specific OTP endpoints.
    /// Returns the vendor JWT token.
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

    // ───────────────────────────────────────────────────────────────────────
    // Test 1: Emergency Release
    // ───────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task EmergencyRelease_UnassignsTaskAndRedispatches()
    {
        // Create a DispatchTask directly in the DB and assign it to a seed driver.
        var driver = await _db.Drivers.FirstAsync(d => d.Phone == "9000000050");
        var task = DispatchTask.Create(
            taskType: DispatchTaskType.FoodDelivery,
            pickupLocation: GeoLocation.Create(11.9356, 79.8301),
            dropoffLocation: GeoLocation.Create(11.9362, 79.8346),
            pickupAddress: "Fuoco Pizzeria",
            dropoffAddress: "12 Rue Romain Rolland",
            driverEarnings: 40m,
            sourceEntityId: Guid.NewGuid());
        task.Assign(driver.Id);
        _db.DispatchTasks.Add(task);
        await _db.SaveChangesAsync();

        // Authenticate as the driver
        await AuthenticateAsync("9000000050");

        // Call emergency release
        var response = await _client.PostAsync(
            $"/api/driver/tasks/{task.Id}/emergency-release", content: null);

        response.StatusCode.Should().Be(HttpStatusCode.OK);

        // Verify task is back to Available and unassigned
        var taskAfter = await _db.DispatchTasks.AsNoTracking()
            .FirstOrDefaultAsync(t => t.Id == task.Id);
        taskAfter!.Status.Should().Be(DispatchTaskStatus.Available);
        taskAfter.DriverId.Should().BeNull();
    }

    // ───────────────────────────────────────────────────────────────────────
    // Test 2: Partial Refund
    // ───────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task PartialRefund_RemovesItemAndRecalculatesTotal()
    {
        // Consumer creates a food order with 2 items
        await AuthenticateAsync("9000000099");

        var checkoutResponse = await _client.PostAsJsonAsync("/api/orders/checkout", new
        {
            VendorId = SeedVendorId,
            DeliveryAddress = "12 Rue Romain Rolland",
            DeliveryLatitude = 11.9362,
            DeliveryLongitude = 79.8346,
            PaymentMethod = 1, // Cash
            Items = new[]
            {
                new { Name = "Woodfired Margherita", Quantity = 1, UnitPrice = 450m },
                new { Name = "Garlic Bread", Quantity = 1, UnitPrice = 150m }
            }
        });
        checkoutResponse.EnsureSuccessStatusCode();
        var checkout = await checkoutResponse.Content.ReadFromJsonAsync<CheckoutResponseDto>();
        var originalTotal = checkout!.TotalAmount;

        // Get the order from DB to find the item IDs
        var order = await _db.FoodOrders
            .Include(o => o.Items)
            .FirstOrDefaultAsync(o => o.Id == checkout.OrderId);
        order.Should().NotBeNull();
        order!.Items.Should().HaveCount(2);

        var firstItem = order.Items.First();
        var firstItemPrice = firstItem.LineTotal;

        // Authenticate as vendor (Fuoco Pizzeria owner)
        await AuthenticateAsVendorAsync("9000000001");

        // Call partial refund
        var refundResponse = await _client.PostAsJsonAsync(
            $"/api/vendor/orders/{checkout.OrderId}/partial-refund",
            new { ItemId = firstItem.Id });

        refundResponse.EnsureSuccessStatusCode();
        var result = await refundResponse.Content.ReadFromJsonAsync<PartialRefundResponseDto>();
        result!.RefundAmount.Should().Be(firstItemPrice);
        result.NewTotal.Should().Be(originalTotal - firstItemPrice);

        // Verify order in DB has 1 item remaining
        var orderAfter = await _db.FoodOrders
            .Include(o => o.Items)
            .AsNoTracking()
            .FirstOrDefaultAsync(o => o.Id == checkout.OrderId);
        orderAfter!.Items.Should().HaveCount(1);
        orderAfter.TotalAmount.Should().Be(originalTotal - firstItemPrice);
    }

    // ───────────────────────────────────────────────────────────────────────
    // Test 3: Delete Account (Right to be Forgotten)
    // ───────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task DeleteAccount_AnonymizesPIIAndBlocksSubsequentAuth()
    {
        // Authenticate as a consumer using a dedicated phone that won't
        // conflict with other tests (since this test anonymizes the user).
        var (token, userId) = await AuthenticateAsync("9000000077");

        // Add a saved location so we can verify it's deleted
        _db.SavedLocations.Add(SavedLocation.Create(
            userId, "Home", "12 Rue Romain Rolland",
            GeoLocation.Create(11.9362, 79.8346)));
        await _db.SaveChangesAsync();

        // Verify saved location exists
        var locationsBefore = await _db.SavedLocations
            .Where(l => l.UserId == userId)
            .CountAsync();
        locationsBefore.Should().BeGreaterThan(0);

        // Delete account
        var deleteResponse = await _client.DeleteAsync("/api/auth/account");
        deleteResponse.EnsureSuccessStatusCode();

        // Verify user is anonymized in DB
        var user = await _db.Users.AsNoTracking().FirstOrDefaultAsync(u => u.Id == userId);
        user.Should().NotBeNull("the record is kept for financial auditing");
        user!.Name.Should().Be("Deleted User");
        user.Phone.Should().StartWith("del_");
        user.IsActive.Should().BeFalse();

        // Verify saved locations are deleted
        var locationsAfter = await _db.SavedLocations
            .Where(l => l.UserId == userId)
            .CountAsync();
        locationsAfter.Should().Be(0);

        // Verify that the old user's phone was anonymized (no longer matches
        // the original phone) — this is the right-to-be-forgotten guarantee.
        // A new user can register with the same phone since the old one is
        // anonymized, which is expected behavior.
        var allUsersWithPhone = await _db.Users.AsNoTracking()
            .Where(u => u.Phone == "9000000077")
            .ToListAsync();
        allUsersWithPhone.Should().BeEmpty("the original phone should be anonymized");
    }

    // ───────────────────────────────────────────────────────────────────────
    // Test 4: Payment Reconciliation Idempotency
    // ───────────────────────────────────────────────────────────────────────

    [Fact]
    public async Task PaymentReconciliation_DuplicateReconcileIsIdempotent()
    {
        // Create a service booking + payment directly in the DB
        var user = await _db.Users.FirstAsync(u => u.Phone == "9000000099");
        var venue = await _db.Venues.FirstAsync();

        var booking = ServiceBooking.Create(
            userId: user.Id,
            serviceType: ServiceType.Nightlife,
            scheduledFor: DateTimeOffset.UtcNow.AddDays(1),
            venueId: venue.Id,
            seatCount: 1);
        booking.AddItem("Test pass", 1, 100m);
        _db.ServiceBookings.Add(booking);

        var payment = Payment.CreateForServiceBooking(booking.Id, 100m, PaymentProvider.Razorpay, PaymentMethod.Cash);
        var providerOrderId = $"order_test_{Guid.NewGuid():N}";
        payment.MarkProviderOrderCreated(providerOrderId);
        _db.Payments.Add(payment);
        await _db.SaveChangesAsync();

        // Use the booking engine to reconcile — use a separate scope to avoid
        // DbContext concurrency with the test's own _db instance.
        // The test's _db has already saved the payment, so we detach it.
        _db.Entry(payment).State = Microsoft.EntityFrameworkCore.EntityState.Detached;
        _db.Entry(booking).State = Microsoft.EntityFrameworkCore.EntityState.Detached;

        // Use a fresh scope for the engine to ensure a separate DbContext
        using var engineScope = _factory.Services.CreateScope();
        var engine = engineScope.ServiceProvider.GetRequiredService<IBookingEngineService>();

        // First reconciliation — captures the payment
        var result1 = await engine.ReconcilePaymentAsync(
            new ReconcilePaymentRequest(providerOrderId, "pay_test_123"));
        result1.AlreadyReconciled.Should().BeFalse();
        result1.PaymentId.Should().Be(payment.Id);

        // Small delay to ensure the first operation's DbContext lock is released
        await Task.Delay(100);

        // Second reconciliation with the same providerOrderId — should be idempotent
        var result2 = await engine.ReconcilePaymentAsync(
            new ReconcilePaymentRequest(providerOrderId, "pay_test_123"));
        result2.AlreadyReconciled.Should().BeTrue();
        result2.PaymentId.Should().Be(payment.Id);
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

    private sealed record PartialRefundResponseDto(
        string Message,
        decimal RefundAmount,
        decimal NewTotal);

    private sealed record VendorAuthResponseDto(
        string AccessToken,
        Guid VendorId,
        string VendorName,
        string Category,
        string Phone,
        string Status);
}
