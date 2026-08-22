namespace PondyConnect.Application.Features.Vendor;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Enums;

/// <summary>
/// Returns all checked-in bookings for the authenticated vendor's venues.
/// Used by the Partner app's "Live Tables" tab to show the cover charge
/// credit ledger — each card represents a table that has been scanned in
/// at the door, with the prepaid cover charge amount available for the
/// waitstaff to track against the final bill.
/// </summary>
public sealed record GetLiveTablesQuery : IRequest<List<LiveTableEntry>>;

public sealed record LiveTableEntry(
    Guid BookingId,
    string GuestName,
    int GuestCount,
    decimal CoverChargeAmount,
    decimal CreditUsed,
    decimal CreditAvailable,
    string ServiceType,
    DateTimeOffset CheckedInAt,
    string Status);

public sealed class GetLiveTablesHandler : IRequestHandler<GetLiveTablesQuery, List<LiveTableEntry>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetLiveTablesHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<List<LiveTableEntry>> Handle(GetLiveTablesQuery request, CancellationToken cancellationToken)
    {
        var phone = _currentUser.Phone;
        if (string.IsNullOrWhiteSpace(phone))
            throw new UnauthorizedAccessException("Authenticated phone not found.");

        // Resolve the vendor from the authenticated phone.
        var vendor = await _context.Vendors
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.ContactPhone == phone && v.IsApproved, cancellationToken)
            ?? throw new UnauthorizedAccessException("Vendor profile not found.");

        // Find all bookings for this vendor that are checked in (active tables).
        var bookings = await _context.ServiceBookings
            .Where(b => b.VendorId == vendor.Id &&
                        (b.Status == BookingStatus.CheckedIn || b.Status == BookingStatus.Confirmed) &&
                        b.PaymentStatus == PaymentStatus.Captured)
            .OrderByDescending(b => b.UpdatedAt)
            .ToListAsync(cancellationToken);

        if (bookings.Count == 0)
            return new List<LiveTableEntry>();

        // Batch-fetch user names for all bookings.
        var userIds = bookings.Select(b => b.UserId).Distinct().ToList();
        var users = await _context.Users
            .AsNoTracking()
            .Where(u => userIds.Contains(u.Id))
            .ToDictionaryAsync(u => u.Id, cancellationToken);

        var result = new List<LiveTableEntry>();
        foreach (var booking in bookings)
        {
            var guestName = users.TryGetValue(booking.UserId, out var user) ? user.Name : "Unknown";
            // Credit used is not yet tracked (future: bill integration).
            // For now, the full cover charge is available as credit.
            var creditUsed = 0m;
            var creditAvailable = booking.TotalAmount - creditUsed;

            result.Add(new LiveTableEntry(
                booking.Id,
                guestName,
                booking.SeatCount,
                booking.TotalAmount,
                creditUsed,
                creditAvailable,
                booking.ServiceType.ToString(),
                booking.UpdatedAt ?? booking.CreatedAt,
                booking.Status.ToString()));
        }

        return result;
    }
}
