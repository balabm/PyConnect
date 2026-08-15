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
/// Tests for CreateBookingCommandHandler: user attribution, validation, and engine integration.
/// Uses the in-memory EF provider (no Postgres/Redis required).
/// </summary>
public sealed class CreateBookingCommandHandlerTests
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

    private sealed class FakeCurrentUser : ICurrentUserService
    {
        public Guid? UserId { get; set; } = Guid.Parse("00000000-0000-0000-0000-000000000042");
        public string? Phone => "9876543210";
        public string? Role => "Tourist";
    }

    private sealed class FakeSettlementService : ISettlementCalculationService
    {
        public Task<SettlementResult> CalculateSettlementAsync(Guid paymentId, CancellationToken cancellationToken = default)
            => Task.FromResult(new SettlementResult(paymentId, 0m, 0m, 0m, 0m, null, null, null, null));
    }

    private static Venue CreateVenue(ApplicationDbContext context, int maxCapacity = 40)
        => Venue.Create("Test Club", VenueCategory.Club, GeoLocation.Create(11.9348, 79.8346), maxCapacity);

    [Fact]
    public async Task CreateBooking_AssignsAuthenticatedUser_NotGuidEmpty()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 40);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var currentUser = new FakeCurrentUser();
        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var handler = new CreateBookingCommandHandler(context, engine, currentUser);

        var result = await handler.Handle(
            new CreateBookingCommand(venue.Id, 2, DateTimeOffset.UtcNow.AddHours(1), "Test booking"),
            CancellationToken.None);

        result.BookingId.Should().NotBeEmpty();

        var booking = await context.ServiceBookings.SingleAsync();
        booking.UserId.Should().Be(currentUser.UserId!.Value);
        booking.UserId.Should().NotBe(Guid.Empty);
    }

    [Fact]
    public async Task CreateBooking_WhenUnauthenticated_ThrowsUnauthorized()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 40);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var currentUser = new FakeCurrentUser { UserId = null };
        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var handler = new CreateBookingCommandHandler(context, engine, currentUser);

        var act = async () => await handler.Handle(
            new CreateBookingCommand(venue.Id, 2, DateTimeOffset.UtcNow.AddHours(1), "Test booking"),
            CancellationToken.None);

        await act.Should().ThrowAsync<UnauthorizedAccessException>()
            .WithMessage("User not authenticated.");
    }

    [Fact]
    public async Task CreateBooking_WhenVenueNotFound_ThrowsInvalidOperation()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 40);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var currentUser = new FakeCurrentUser();
        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var handler = new CreateBookingCommandHandler(context, engine, currentUser);

        var act = async () => await handler.Handle(
            new CreateBookingCommand(Guid.NewGuid(), 2, DateTimeOffset.UtcNow.AddHours(1), "Test booking"),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Venue not found or is not active.");
    }

    [Fact]
    public async Task CreateBooking_WhenVenueInactive_ThrowsInvalidOperation()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 40);
        venue.ToggleActive(false);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var currentUser = new FakeCurrentUser();
        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var handler = new CreateBookingCommandHandler(context, engine, currentUser);

        var act = async () => await handler.Handle(
            new CreateBookingCommand(venue.Id, 2, DateTimeOffset.UtcNow.AddHours(1), "Test booking"),
            CancellationToken.None);

        await act.Should().ThrowAsync<InvalidOperationException>()
            .WithMessage("Venue not found or is not active.");
    }

    [Fact]
    public async Task CreateBooking_WhenCapacityExhausted_ThrowsConflict()
    {
        using var context = CreateContext();
        var venue = CreateVenue(context, maxCapacity: 2);
        context.Venues.Add(venue);
        await context.SaveChangesAsync();

        var currentUser = new FakeCurrentUser();
        var engine = new BookingEngineService(context, new InMemoryDistributedLock(), new FakeAvailabilityCache(), new FakeSettlementService());
        var handler = new CreateBookingCommandHandler(context, engine, currentUser);

        await handler.Handle(
            new CreateBookingCommand(venue.Id, 2, DateTimeOffset.UtcNow.AddHours(1), "First"),
            CancellationToken.None);

        var act = async () => await handler.Handle(
            new CreateBookingCommand(venue.Id, 1, DateTimeOffset.UtcNow.AddHours(2), "Second"),
            CancellationToken.None);

        await act.Should().ThrowAsync<BookingConflictException>();
    }
}