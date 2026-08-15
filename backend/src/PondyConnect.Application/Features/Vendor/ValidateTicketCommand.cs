namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record ValidateTicketCommand(string QrPayload) : IRequest<TicketValidationResponse>;

public sealed record TicketValidationResponse(
    bool IsValid,
    string ServiceType,
    string UserName,
    string Message,
    bool IsDuplicate = false,
    string? PreviousScanAt = null);

public sealed class ValidateTicketHandler : IRequestHandler<ValidateTicketCommand, TicketValidationResponse>
{
    private readonly IApplicationDbContext _context;

    public ValidateTicketHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<TicketValidationResponse> Handle(ValidateTicketCommand request, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(request.QrPayload))
            return new TicketValidationResponse(false, string.Empty, string.Empty, "Empty QR payload.");

        // Check ServiceBooking passes via stored PassToken (indexed lookup)
        var booking = await _context.ServiceBookings
            .FirstOrDefaultAsync(b => b.PassToken == request.QrPayload, cancellationToken);

        if (booking is not null)
        {
            if (booking.PaymentStatus != PaymentStatus.Captured)
                return new TicketValidationResponse(false, booking.ServiceType.ToString(), string.Empty, "Payment not captured.");

            if (booking.Status == BookingStatus.CheckedIn || booking.Status == BookingStatus.Completed)
                return new TicketValidationResponse(false, booking.ServiceType.ToString(), string.Empty, "Already used.", IsDuplicate: true, PreviousScanAt: booking.UpdatedAt?.ToString("o"));

            if (booking.Status != BookingStatus.Confirmed)
                return new TicketValidationResponse(false, booking.ServiceType.ToString(), string.Empty, "Booking not confirmed.");

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == booking.UserId, cancellationToken);

            booking.CheckIn();

            // Increment venue checked-in count if booking is linked to a venue
            if (booking.VenueId is { } venueId && booking.SeatCount > 0)
            {
                var venue = await _context.Venues
                    .FirstOrDefaultAsync(v => v.Id == venueId, cancellationToken);
                if (venue is not null)
                    venue.IncrementCheckedIn(booking.SeatCount);
            }

            await _context.SaveChangesAsync(cancellationToken);

            var userName = user?.Name ?? "Unknown";
            return new TicketValidationResponse(true, booking.ServiceType.ToString(), userName, "Valid ticket.");
        }

        // Check BundleBooking passes (PassToken stored on entity)
        var bundle = await _context.BundleBookings
            .FirstOrDefaultAsync(b => b.PassToken == request.QrPayload, cancellationToken);

        if (bundle is not null)
        {
            if (bundle.Status == BundleStatus.Cancelled)
                return new TicketValidationResponse(false, "Long Weekend Pass", string.Empty, "Pass cancelled.");

            if (bundle.Status == BundleStatus.FullyRedeemed)
                return new TicketValidationResponse(false, "Long Weekend Pass", string.Empty, "Already used.", IsDuplicate: true, PreviousScanAt: bundle.UpdatedAt?.ToString("o"));

            var user = await _context.Users.AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == bundle.UserId, cancellationToken);

            bundle.MarkPartiallyRedeemed();
            await _context.SaveChangesAsync(cancellationToken);

            var userName = user?.Name ?? "Unknown";
            return new TicketValidationResponse(true, "Long Weekend Pass", userName, "Valid pass.");
        }

        return new TicketValidationResponse(false, string.Empty, string.Empty, "Unknown ticket.");
    }
}
