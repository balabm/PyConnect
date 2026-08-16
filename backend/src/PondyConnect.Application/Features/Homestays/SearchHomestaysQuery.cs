namespace PondyConnect.Application.Features.Homestays;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed record SearchHomestaysQuery(
    DateOnly CheckIn,
    DateOnly CheckOut,
    int Guests) : IRequest<IReadOnlyList<HomestaySearchResult>>;

public sealed record HomestaySearchResult(
    Guid Id,
    string Name,
    string Description,
    string LocationArea,
    double Latitude,
    double Longitude,
    decimal NightlyRate,
    int MaxGuests,
    bool HasWifi,
    bool IsVerified,
    IReadOnlyList<DateOnly> UnavailableDates);

public sealed class SearchHomestaysQueryHandler : IRequestHandler<SearchHomestaysQuery, IReadOnlyList<HomestaySearchResult>>
{
    private readonly IApplicationDbContext _context;

    public SearchHomestaysQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<HomestaySearchResult>> Handle(
        SearchHomestaysQuery request,
        CancellationToken cancellationToken)
    {
        var homestays = await _context.Homestays
            .Where(h => h.IsVerified && h.MaxGuests >= request.Guests)
            .ToListAsync(cancellationToken);

        var homestayIds = homestays.Select(h => h.Id).ToList();

        var bookedEntries = await _context.RoomAvailabilities
            .Where(r => homestayIds.Contains(r.HomestayId)
                && r.Date >= request.CheckIn
                && r.Date < request.CheckOut
                && r.IsBooked)
            .ToListAsync(cancellationToken);

        var bookedHomestayIds = bookedEntries.Select(r => r.HomestayId).ToHashSet();

        var available = homestays.Where(h => !bookedHomestayIds.Contains(h.Id)).ToList();

        return available
            .Select(h => new HomestaySearchResult(
                h.Id,
                h.Name,
                h.Description,
                h.LocationArea,
                h.Latitude,
                h.Longitude,
                h.NightlyRate,
                h.MaxGuests,
                h.HasWifi,
                h.IsVerified,
                Array.Empty<DateOnly>()))
            .ToList();
    }
}

public sealed record GetHomestayByIdQuery(Guid Id) : IRequest<HomestaySearchResult?>;

public sealed class GetHomestayByIdQueryHandler : IRequestHandler<GetHomestayByIdQuery, HomestaySearchResult?>
{
    private readonly IApplicationDbContext _context;

    public GetHomestayByIdQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<HomestaySearchResult?> Handle(
        GetHomestayByIdQuery request,
        CancellationToken cancellationToken)
    {
        var homestay = await _context.Homestays
            .FirstOrDefaultAsync(h => h.Id == request.Id, cancellationToken);

        if (homestay is null)
            return null;

        var bookings = await _context.ServiceBookings
            .Where(b => b.HomestayId == homestay.Id && b.Status != BookingStatus.Cancelled)
            .Where(b => b.CheckInDate.HasValue && b.CheckOutDate.HasValue)
            .ToListAsync(cancellationToken);

        var unavailableDates = new HashSet<DateOnly>();
        foreach (var booking in bookings)
        {
            var start = booking.CheckInDate!.Value;
            var end = booking.CheckOutDate!.Value;
            for (var d = start; d < end; d = d.AddDays(1))
            {
                unavailableDates.Add(d);
            }
        }

        return new HomestaySearchResult(
            homestay.Id,
            homestay.Name,
            homestay.Description,
            homestay.LocationArea,
            homestay.Latitude,
            homestay.Longitude,
            homestay.NightlyRate,
            homestay.MaxGuests,
            homestay.HasWifi,
            homestay.IsVerified,
            unavailableDates.OrderBy(d => d).ToList());
    }
}

public sealed record ListVerifiedHomestaysQuery() : IRequest<IReadOnlyList<HomestaySearchResult>>;

public sealed class ListVerifiedHomestaysQueryHandler : IRequestHandler<ListVerifiedHomestaysQuery, IReadOnlyList<HomestaySearchResult>>
{
    private readonly IApplicationDbContext _context;

    public ListVerifiedHomestaysQueryHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<HomestaySearchResult>> Handle(
        ListVerifiedHomestaysQuery request,
        CancellationToken cancellationToken)
    {
        var homestays = await _context.Homestays
            .Where(h => h.IsVerified)
            .ToListAsync(cancellationToken);

        return homestays
            .Select(h => new HomestaySearchResult(
                h.Id,
                h.Name,
                h.Description,
                h.LocationArea,
                h.Latitude,
                h.Longitude,
                h.NightlyRate,
                h.MaxGuests,
                h.HasWifi,
                h.IsVerified,
                Array.Empty<DateOnly>()))
            .ToList();
    }
}
