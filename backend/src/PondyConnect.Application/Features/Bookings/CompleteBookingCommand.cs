namespace PondyConnect.Application.Features.Bookings;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

public sealed record CompleteBookingCommand(Guid BookingId) : IRequest<CompleteBookingResponse>;

public sealed record CompleteBookingResponse(Guid BookingId, string Status, DateTimeOffset CompletedAt);

public sealed class CompleteBookingCommandValidator : AbstractValidator<CompleteBookingCommand>
{
    public CompleteBookingCommandValidator()
    {
        RuleFor(x => x.BookingId).NotEmpty();
    }
}

public sealed class CompleteBookingHandler : IRequestHandler<CompleteBookingCommand, CompleteBookingResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IDistributedLock _distributedLock;

    public CompleteBookingHandler(IApplicationDbContext context, ICurrentUserService currentUser, IDistributedLock distributedLock)
    {
        _context = context;
        _currentUser = currentUser;
        _distributedLock = distributedLock;
    }

    public async Task<CompleteBookingResponse> Handle(CompleteBookingCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var booking = await _context.ServiceBookings
            .FirstOrDefaultAsync(b => b.Id == request.BookingId, cancellationToken)
            ?? throw new InvalidOperationException("Booking not found.");

        if (booking.UserId != userId)
            throw new UnauthorizedAccessException("Access denied to this booking.");

        if (booking.Status == BookingStatus.Completed)
            throw new InvalidOperationException("Booking is already completed.");

        if (booking.Status == BookingStatus.Cancelled)
            throw new InvalidOperationException("Cannot complete a cancelled booking.");

        var seatCount = booking.SeatCount;
        var wasCheckedIn = booking.Status == BookingStatus.CheckedIn;

        booking.Complete();

        if (booking.VenueId is { } venueId && seatCount > 0)
        {
            await using var lease = await _distributedLock.TryAcquireAsync(
                $"venue:slot:{venueId}",
                TimeSpan.FromSeconds(30),
                TimeSpan.FromSeconds(5),
                cancellationToken);

            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == venueId, cancellationToken);
            if (venue is not null)
            {
                if (wasCheckedIn)
                    venue.CompleteCheckOut(seatCount);
                else
                    venue.DecreaseOccupancy(seatCount);
            }
        }

        await _context.SaveChangesAsync(cancellationToken);

        return new CompleteBookingResponse(booking.Id, booking.Status.ToString(), booking.CompletedAt ?? DateTimeOffset.UtcNow);
    }
}
