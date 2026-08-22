namespace PondyConnect.Application.Features.Bookings;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Returns the signed QR pass token and booking details for the consumer
/// ticket screen. The QR payload is the cryptographically signed
/// PassToken stored on the booking, which the bouncer's scanner validates
/// against the backend.
/// </summary>
public sealed record GetTicketQuery(Guid BookingId) : IRequest<TicketResponse>;

public sealed record TicketResponse(
    Guid BookingId,
    string PassToken,
    string ServiceType,
    string Status,
    decimal TotalAmount,
    int SeatCount,
    string VenueName,
    DateTimeOffset ScheduledFor,
    string? Notes);

public sealed class GetTicketQueryHandler : IRequestHandler<GetTicketQuery, TicketResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetTicketQueryHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<TicketResponse> Handle(GetTicketQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        if (userId == Guid.Empty)
            throw new UnauthorizedAccessException("User not authenticated.");

        var booking = await _context.ServiceBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == request.BookingId && b.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Booking not found or does not belong to you.");

        // Resolve venue name if the booking is linked to a venue.
        string? venueName = null;
        if (booking.VenueId is { } venueId)
        {
            var venue = await _context.Venues
                .AsNoTracking()
                .FirstOrDefaultAsync(v => v.Id == venueId, cancellationToken);
            venueName = venue?.Name;
        }

        // Use the stored PassToken, or generate one if it doesn't exist yet.
        var passToken = booking.PassToken ?? PassIssuer.IssueSigned(
            booking.Id, booking.UserId, booking.TotalAmount, booking.ScheduledFor);

        return new TicketResponse(
            booking.Id,
            passToken,
            booking.ServiceType.ToString(),
            booking.Status.ToString(),
            booking.TotalAmount,
            booking.SeatCount,
            venueName ?? "Venue",
            booking.ScheduledFor,
            booking.Notes);
    }
}
