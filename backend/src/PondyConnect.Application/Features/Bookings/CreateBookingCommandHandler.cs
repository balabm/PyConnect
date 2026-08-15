namespace PondyConnect.Application.Features.Bookings;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;

public sealed class CreateBookingCommandHandler : IRequestHandler<CreateBookingCommand, CreateBookingResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IBookingEngineService _bookingEngine;
    private readonly ICurrentUserService _currentUser;

    public CreateBookingCommandHandler(IApplicationDbContext context, IBookingEngineService bookingEngine, ICurrentUserService currentUser)
    {
        _context = context;
        _bookingEngine = bookingEngine;
        _currentUser = currentUser;
    }

    public async Task<CreateBookingResponse> Handle(CreateBookingCommand request, CancellationToken cancellationToken)
    {
        // Validate the venue is active up front; the authoritative capacity
        // check and occupancy write happen under the venue slot lock inside
        // the booking engine.
        var venue = await _context.Venues
            .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.IsActive, cancellationToken)
            ?? throw new InvalidOperationException("Venue not found or is not active.");

        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var reservation = await _bookingEngine.ReserveVenueSlotAsync(
            new ReserveVenueSlotRequest(
                VenueId: request.VenueId,
                UserId: userId,
                Seats: request.Seats,
                ScheduledFor: request.ScheduledFor,
                Notes: request.Notes),
            cancellationToken);

        return new CreateBookingResponse(reservation.BookingId, reservation.Status, reservation.Amount, reservation.PassToken);
    }
}