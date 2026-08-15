namespace PondyConnect.Application.Features.Venues;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class VenueFilterQueryHandler : IRequestHandler<VenueFilterQuery, IReadOnlyList<VenueFilterResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly IAvailabilityCache _availabilityCache;

    public VenueFilterQueryHandler(IApplicationDbContext context, IAvailabilityCache availabilityCache)
    {
        _context = context;
        _availabilityCache = availabilityCache;
    }

    public async Task<IReadOnlyList<VenueFilterResponse>> Handle(VenueFilterQuery request, CancellationToken cancellationToken)
    {
        var query = _context.Venues
            .AsNoTracking()
            .Where(v => !request.OnlyActive || v.IsActive);

        VenueCategory? categoryFilter = null;
        if (request.Category is not null && Enum.IsDefined(typeof(VenueCategory), request.Category.Value))
            categoryFilter = (VenueCategory)request.Category.Value;

        if (_context.IsPostgreSQL && categoryFilter is not null)
            query = query.Where(v => v.Category == categoryFilter.Value);

        var allVenues = await query
            .OrderBy(v => v.Name)
            .ToListAsync(cancellationToken);

        var venues = (!_context.IsPostgreSQL && categoryFilter is not null
            ? allVenues.Where(v => v.Category == categoryFilter.Value)
            : allVenues)
            .OrderByDescending(v => v.IsPriorityPingActive && (v.PriorityPingExpiry == null || v.PriorityPingExpiry > DateTimeOffset.UtcNow))
            .ThenBy(v => v.Name)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .ToList();

        var live = await _availabilityCache.GetOccupanciesAsync(venues.Select(v => v.Id).ToList(), cancellationToken);

        var now = TimeOnly.FromDateTime(DateTime.UtcNow.AddMinutes(330)); // IST
        var dayOfWeek = DateTime.UtcNow.DayOfWeek;
        return venues
            .Select(v =>
            {
                var occupancy = live.TryGetValue(v.Id, out var cached) ? cached : v.CurrentCapacity;
                var isOpen = v.Availability.Count == 0 ||
                             v.Availability.Any(a =>
                                 a.DayOfWeek == dayOfWeek &&
                                 a.OpensAt <= now &&
                                 now <= a.ClosesAt);
                var priorityActive = v.IsPriorityPingActive &&
                    (v.PriorityPingExpiry == null || v.PriorityPingExpiry > DateTimeOffset.UtcNow);
                return new VenueFilterResponse(
                    v.Id,
                    v.Name,
                    v.Category.ToString(),
                    v.Location.Latitude,
                    v.Location.Longitude,
                    occupancy,
                    IsOpen: isOpen,
                    v.Address,
                    priorityActive,
                    v.ImageUrl,
                    v.Rating,
                    v.ReviewCount);
            })
            .ToList();
    }
}