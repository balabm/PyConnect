namespace PondyConnect.Application.Features.Homestays;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

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
    bool IsVerified);

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
                h.IsVerified))
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
            homestay.IsVerified);
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
                h.IsVerified))
            .ToList();
    }
}
