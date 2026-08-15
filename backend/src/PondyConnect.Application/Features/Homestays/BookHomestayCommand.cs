namespace PondyConnect.Application.Features.Homestays;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Bookings;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record BookHomestayCommand(
    Guid HomestayId,
    DateOnly CheckIn,
    DateOnly CheckOut,
    int Guests,
    bool AddScooterPickup = false,
    bool AddLuggageCloak = false) : IRequest<BookHomestayResponse>;

public sealed record BookHomestayResponse(
    Guid BookingId,
    decimal TotalAmount,
    string PassToken,
    string Status,
    IReadOnlyList<AddOnSuggestion> SuggestedAddOns);

public sealed class BookHomestayCommandValidator : AbstractValidator<BookHomestayCommand>
{
    public BookHomestayCommandValidator()
    {
        RuleFor(x => x.HomestayId).NotEmpty();
        RuleFor(x => x.Guests).InclusiveBetween(1, 20);
        RuleFor(x => x.CheckIn).LessThan(x => x.CheckOut);
    }
}

public sealed class BookHomestayCommandHandler : IRequestHandler<BookHomestayCommand, BookHomestayResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public BookHomestayCommandHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<BookHomestayResponse> Handle(
        BookHomestayCommand request,
        CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User is not authenticated.");

        var homestay = await _context.Homestays
            .FirstOrDefaultAsync(h => h.Id == request.HomestayId && h.IsVerified, cancellationToken)
            ?? throw new InvalidOperationException("Homestay not found or not verified.");

        if (homestay.MaxGuests < request.Guests)
            throw new InvalidOperationException($"Homestay accommodates up to {homestay.MaxGuests} guests.");

        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);

        try
        {
            var nights = request.CheckOut.DayNumber - request.CheckIn.DayNumber;
            if (nights <= 0)
                throw new InvalidOperationException("Check-out must be at least one day after check-in.");

            var availabilityEntries = await _context.RoomAvailabilities
                .Where(r => r.HomestayId == request.HomestayId
                    && r.Date >= request.CheckIn
                    && r.Date < request.CheckOut)
                .ToListAsync(cancellationToken);

            if (availabilityEntries.Count != nights)
                throw new InvalidOperationException("Room availability not initialized for the requested date range.");

            if (availabilityEntries.Any(r => r.IsBooked))
                throw new InvalidOperationException("Homestay is not available for the selected dates.");

            // Use UTC offset — Npgsql 6+ requires UTC DateTimeOffset for timestamptz columns.
            // The 12:00 IST check-in time is stored as 06:30 UTC (offset 0).
            var checkInDateTime = new DateTimeOffset(
                request.CheckIn,
                new TimeOnly(6, 30),
                TimeSpan.Zero);

            var booking = ServiceBooking.Create(
                userId: userId,
                serviceType: ServiceType.Homestay,
                scheduledFor: checkInDateTime,
                amount: 0m,
                checkInDate: request.CheckIn,
                checkOutDate: request.CheckOut,
                homestayId: request.HomestayId);

            booking.AddItem($"Homestay stay ({nights} nights)", nights, homestay.NightlyRate);

            ScooterRental? scooterRental = null;
            LuggageDropOff? luggageDropOff = null;

            if (request.AddScooterPickup)
            {
                var firstVendorId = await _context.Vendors
                    .Select(v => v.Id)
                    .FirstOrDefaultAsync(cancellationToken);

                if (firstVendorId != Guid.Empty)
                {
                    var scooterPrice = 300m * nights * 0.9m;
                    scooterRental = ScooterRental.Create(
                        userId: userId,
                        vendorId: firstVendorId,
                        vehicleName: "Scooter Pick-up at Bus Stand",
                        rentalStart: checkInDateTime,
                        rentalEnd: checkInDateTime.AddHours(24 * nights),
                        ratePerHour: scooterPrice / (24m * nights));

                    booking.AddItem("Scooter Pick-up (10% off)", 1, scooterPrice);
                    _context.ScooterRentals.Add(scooterRental);
                }
            }

            if (request.AddLuggageCloak)
            {
                var firstVendorId = await _context.Vendors
                    .Select(v => v.Id)
                    .FirstOrDefaultAsync(cancellationToken);

                if (firstVendorId != Guid.Empty)
                {
                    luggageDropOff = LuggageDropOff.Create(
                        userId: userId,
                        vendorId: firstVendorId,
                        scheduledFor: checkInDateTime,
                        droppedAt: checkInDateTime,
                        bagCount: 1,
                        ratePerHour: 0m);

                    booking.AddItem("Early Arrival Luggage Cloak (Free with stay)", 1, 0m);
                    _context.LuggageDropOffs.Add(luggageDropOff);
                }
            }

            foreach (var entry in availabilityEntries)
            {
                entry.Lock(booking.Id);
            }

            _context.ServiceBookings.Add(booking);
            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            var pass = PassIssuer.Issue(booking.Id, booking.TotalAmount, checkInDateTime);

            var suggestions = StayBundlingService.GenerateAddOnSuggestions(
                checkInDateTime,
                hasTransitBooking: request.AddScooterPickup,
                hasLuggageBooking: request.AddLuggageCloak);

            return new BookHomestayResponse(
                booking.Id,
                booking.TotalAmount,
                pass,
                booking.Status.ToString(),
                suggestions);
        }
        catch
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }
}
