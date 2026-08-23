namespace PondyConnect.Application.Features.Venues;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class GetVenueByIdQueryHandler : IRequestHandler<GetVenueByIdQuery, VenueDetailResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly IAvailabilityCache _availabilityCache;

    public GetVenueByIdQueryHandler(IApplicationDbContext context, IAvailabilityCache availabilityCache)
    {
        _context = context;
        _availabilityCache = availabilityCache;
    }

    public async Task<VenueDetailResponse> Handle(GetVenueByIdQuery request, CancellationToken cancellationToken)
    {
        var venue = await _context.Venues
            .AsNoTracking()
            .Where(v => v.Id == request.Id && v.IsActive)
            .Select(v => new
            {
                v.Id,
                v.Name,
                v.Category,
                v.Location,
                v.MaxCapacity,
                v.CurrentCapacity,
                v.Address,
                v.Description,
                v.ImageUrl,
                v.Rating,
                v.ReviewCount,
                v.IsPriorityPingActive,
                v.PriorityPingExpiry,
                v.Availability
            })
            .FirstOrDefaultAsync(cancellationToken)
            ?? throw new InvalidOperationException("Venue not found or is not active.");

        var currentCapacity = venue.CurrentCapacity;
        var cached = await _availabilityCache.GetVenueOccupancyAsync(venue.Id, cancellationToken);
        if (cached.HasValue) currentCapacity = cached.Value;

        var occupancyPct = venue.MaxCapacity > 0
            ? (int)Math.Round((double)currentCapacity / venue.MaxCapacity * 100)
            : 0;

        var now = TimeOnly.FromDateTime(DateTime.UtcNow.AddMinutes(330)); // IST
        var dayOfWeek = DateTime.UtcNow.DayOfWeek;
        var isOpen = venue.Availability.Count == 0 ||
                     venue.Availability.Any(a =>
                         a.DayOfWeek == dayOfWeek &&
                         a.OpensAt <= now &&
                         now <= a.ClosesAt);

        var priorityActive = venue.IsPriorityPingActive &&
            (venue.PriorityPingExpiry == null || venue.PriorityPingExpiry > DateTimeOffset.UtcNow);

        return new VenueDetailResponse(
            venue.Id,
            venue.Name,
            venue.Category.ToString(),
            venue.Location.Latitude,
            venue.Location.Longitude,
            venue.MaxCapacity,
            occupancyPct,
            isOpen,
            venue.Address,
            venue.Description,
            venue.ImageUrl,
            venue.Rating,
            venue.ReviewCount,
            priorityActive,
            venue.Availability
                .OrderBy(a => a.DayOfWeek)
                .Select(a => new VenueAvailabilityResponse(a.DayOfWeek, a.OpensAt, a.ClosesAt))
                .ToList());
    }
}