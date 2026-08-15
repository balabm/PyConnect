namespace PondyConnect.Architecture.Tests;

using FluentAssertions;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Application.Features.Settlement;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Infrastructure.Locking;
using PondyConnect.Infrastructure.Persistence;

/// <summary>
/// End-to-end tests for the BookingEngineService: zero-overbooking under
/// concurrency, idempotent payment reconciliation and bundle rollback.
/// Uses the in-process lock and the EF in-memory provider (no Redis/Postgres).
/// </summary>
public sealed class BookingEngineTests
{
    private static ApplicationDbContext CreateContext(string? dbName = null)
    {
        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseInMemoryDatabase(dbName ?? Guid.NewGuid().ToString())
            .Options;
        return new ApplicationDbContext(options);
    }

    private sealed class FakeAvailabilityCache : IAvailabilityCache
    {
        public Dictionary<Guid, int> Occupancy { get; } = [];

        public Task<int?> GetVenueOccupancyAsync(Guid venueId, CancellationToken ct = default)
            => Task.FromResult<int?>(Occupancy.TryGetValue(venueId, out var v) ? v : null);

        public Task SetVenueOccupancyAsync(Guid venueId, int occupancy, TimeSpan? expiry = null, CancellationToken ct = default)
        {
            Occupancy[venueId] = occupancy;
            return Task.CompletedTask;
        }

        public Task RemoveVenueOccupancyAsync(Guid venueId, CancellationToken ct = default)
        {
            Occupancy.Remove(venueId);
            return Task.CompletedTask;
        }

        public Task<IReadOnlyDictionary<Guid, int>> GetOccupanciesAsync(IReadOnlyCollection<Guid> venueIds, CancellationToken ct = default)
        {
            var result = (IReadOnlyDictionary<Guid, int>)venueIds
                .Where(Occupancy.ContainsKey)
                .ToDictionary(id => id, id => Occupancy[id]);
            return Task.FromResult<IReadOnlyDictionary<Guid, int>>(result);
        }
    }

    private static Venue CreateVenue(ApplicationDbContext context, int maxCapacity = 40)
        => Venue.Create("Club Mirage", VenueCategory.Club, GeoLocation.Create(11.9348, 79.8346), maxCapacity);

    [Fact]
    public async Task ReserveVenueSlot_AllocatesCapacity_AndPersistsBooking()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 40);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var result = await engine.ReserveVenueSlotAsync(
            new ReserveVenueSlotRequest(venue.Id, Guid.Parse("00000000-0000-0000-0000-000000000001"), 2, DateTimeOffset.UtcNow.AddHours(1)),
            CancellationToken.None);

        result.BookingId.Should().NotBeEmpty();
        result.Status.Should().Be("Pending");
        result.Amount.Should().Be(500m * 2);
        result.PassToken.Should().NotBeNullOrWhiteSpace();

        await context.Entry(venue).ReloadAsync();
        venue.CurrentCapacity.Should().Be(2);

        var booking = await context.ServiceBookings.SingleAsync();
        booking.PaymentStatus.Should().Be(PaymentStatus.Unpaid);
    }

    [Fact]
    public async Task ReserveVenue_WhenCapacityExhausted_ThrowsAndPersistsNothing()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 2);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());

        await engine.ReserveVenueSlotAsync(
            new ReserveVenueSlotRequest(venue.Id, Guid.NewGuid(), 2, DateTimeOffset.UtcNow.AddHours(1)),
            CancellationToken.None);

        var act = async () => await engine.ReserveVenueSlotAsync(
            new ReserveVenueSlotRequest(venue.Id, Guid.NewGuid(), 552, DateTimeOffset.UtcNow.AddHours(2)),
            CancellationToken.None);

        await act.Should().ThrowAsync<BookingConflictException>();
        context.ServiceBookings.Count().Should().Be(1);
        (await context.Venues.SingleAsync()).CurrentCapacity.Should().Be(2);
    }

    [Fact]
    public async Task ConcurrentReservations_NeverOverbook()
    {
        using var context = CreateContext("concurrency-test");
        var venue = CreateVenue(context, maxCapacity: 3);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());

        var outcomes = (await Task.WhenAll(
            Enumerable.Range(0, 6).Select(i => engine.ReserveVenueSlotAsync(
                new ReserveVenueSlotRequest(venue.Id, Guid.NewGuid(), 1, DateTimeOffset.UtcNow.AddHours(i + 1)),
                CancellationToken.None)
                .ContinueWith(t => t.IsCompletedSuccessfully ? BookingOutcome.Succeeded : BookingOutcome.Denied))))
            .ToList();

        outcomes.Count(o => o == BookingOutcome.Succeeded).Should().Be(3);

        await context.Entry(venue).ReloadAsync();
        venue.CurrentCapacity.Should().Be(3);
    }

    private enum BookingOutcome { Succeeded, Denied }

    private sealed class FakeSettlementService : ISettlementCalculationService
    {
        public Task<SettlementResult> CalculateSettlementAsync(Guid paymentId, CancellationToken cancellationToken = default)
        {
            return Task.FromResult(new SettlementResult(paymentId, 0m, 0m, 0m, 0m, null, null, null, null));
        }
    }

    [Fact]
    public async Task ReserveBundle_RollsBack_WhenTransitHubMissing()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 20);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());

        var act = () => engine.ReserveBundleAsync(
            new ReserveBundleRequest(
                UserId: Guid.NewGuid(),
                VenueId: venue.Id,
                VenueSeats: 2,
                ScheduledFor: DateTimeOffset.UtcNow.AddHours(1),
                TransitLeg: new ReserveTransitLeg(
                    HubId: Guid.NewGuid(),
                    ArrivalFrom: "Chennai",
                    ArrivalMode: "Bus",
                    ArrivalAt: DateTimeOffset.UtcNow.AddHours(2),
                    PartySize: 2,
                    Price: 400m)),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>();
        context.ServiceBookings.Count().Should().Be(0);

        // InMemory has no real transaction; read from the store (untracked) to
        // confirm nothing was persisted, mirroring a Postgres rollback.
        var persisted = await context.Venues.AsNoTracking().SingleAsync();
        persisted.CurrentCapacity.Should().Be(0);
    }

    [Fact]
    public async Task ReconcilePayment_IsIdempotent_IssuesSamePass()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 20);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());

        var reservation = await engine.ReserveVenueSlotAsync(
            new ReserveVenueSlotRequest(venue.Id, Guid.NewGuid(), 2, DateTimeOffset.UtcNow.AddHours(1)),
            CancellationToken.None);

        var payment = Payment.CreateForServiceBooking(reservation.BookingId, reservation.Amount);
        payment.MarkProviderOrderCreated("order_razorpay_1");
        context.Payments.Add(payment);
        await context.SaveChangesAsync();

        var first = await engine.ReconcilePaymentAsync(
            new ReconcilePaymentRequest("order_razorpay_1", "pay_razorpay_1"),
            CancellationToken.None);
        first.AlreadyReconciled.Should().BeFalse();
        first.ServiceBookingId.Should().Be(reservation.BookingId);
        first.PassToken.Should().NotBeNullOrWhiteSpace();

        var bookingAfter = await context.ServiceBookings.SingleAsync();
        bookingAfter.PaymentStatus.Should().Be(PaymentStatus.Captured);
        bookingAfter.Status.Should().Be(BookingStatus.Confirmed);

        var again = await engine.ReconcilePaymentAsync(
            new ReconcilePaymentRequest("order_razorpay_1", "pay_razorpay_1"),
            CancellationToken.None);
        again.AlreadyReconciled.Should().BeTrue();
        again.PassToken.Should().Be(first.PassToken);
    }
}