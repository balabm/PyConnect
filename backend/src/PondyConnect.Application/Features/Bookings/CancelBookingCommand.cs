namespace PondyConnect.Application.Features.Bookings;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record CancelBookingCommand(Guid BookingId) : IRequest<CancelBookingResponse>;

public sealed record CancelBookingResponse(Guid BookingId, string Status, int FreedSeats);

public sealed class CancelBookingCommandValidator : AbstractValidator<CancelBookingCommand>
{
    public CancelBookingCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
    }
}

public sealed class CancelBookingHandler : IRequestHandler<CancelBookingCommand, CancelBookingResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IDistributedLock _distributedLock;

    public CancelBookingHandler(IApplicationDbContext context, ICurrentUserService currentUser, IDistributedLock distributedLock)
    {
        _context = context;
        _currentUser = currentUser;
        _distributedLock = distributedLock;
    }

    public async Task<CancelBookingResponse> Handle(CancelBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var booking = await _context.ServiceBookings
            .FirstOrDefaultAsync(b => b.Id == request.BookingId, cancellationToken)
            ?? throw new InvalidOperationException("Booking not found.");

        if (booking.UserId != userId)
            throw new UnauthorizedAccessException("Access denied to this booking.");

        if (booking.Status == BookingStatus.Cancelled)
            throw new InvalidOperationException("Booking is already cancelled.");

        if (booking.Status == BookingStatus.Completed)
            throw new InvalidOperationException("Cannot cancel a completed booking.");

        var freedSeats = booking.SeatCount;

        booking.Cancel();

        if (booking.VenueId is { } venueId && freedSeats > 0)
        {
            await using var lease = await _distributedLock.TryAcquireAsync(
                $"venue:slot:{venueId}",
                TimeSpan.FromSeconds(30),
                TimeSpan.FromSeconds(5),
                cancellationToken);

            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == venueId, cancellationToken);
            if (venue is not null)
                venue.DecreaseOccupancy(freedSeats);
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new CancelBookingResponse(booking.Id, booking.Status.ToString(), freedSeats);
    }
}
