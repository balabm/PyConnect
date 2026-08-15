namespace PondyConnect.Application.Features.Transit;

using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

public sealed class CreateTransitTripHandler : IRequestHandler<CreateTransitTripCommand, CreateTransitTripResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CreateTransitTripHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CreateTransitTripResponse> Handle(CreateTransitTripCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        
        var hub = await _context.TransitHubs
            .FirstOrDefaultAsync(h => h.Id == request.HubId && h.IsActive, cancellationToken)
            ?? throw new InvalidOperationException("Transit hub not found or inactive.");

        var trip = TransitTrip.Create(
            userId: userId,
            hubId: request.HubId,
            arrivalFrom: request.ArrivalFrom,
            arrivalMode: request.ArrivalMode,
            arrivalAt: request.ArrivalAt,
            partySize: request.PartySize,
            price: request.Price,
            dropOffLocation: request.DropOffLocation,
            notes: request.Notes);

        _context.TransitTrips.Add(trip);
        await _context.SaveChangesAsync(cancellationToken);

        return new CreateTransitTripResponse(trip.Id, trip.Status.ToString(), trip.Price);
    }
}

public sealed class ListTransitHubsHandler : IRequestHandler<ListTransitHubsQuery, IReadOnlyList<TransitHubResponse>>
{
    private readonly IApplicationDbContext _context;

    public ListTransitHubsHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<IReadOnlyList<TransitHubResponse>> Handle(ListTransitHubsQuery request, CancellationToken cancellationToken)
    {
        var query = _context.TransitHubs.AsNoTracking();
        if (request.OnlyActive)
            query = query.Where(h => h.IsActive);
        if (request.Kind.HasValue)
            query = query.Where(h => h.Kind == request.Kind.Value);

        return await query
            .OrderBy(h => h.Name)
            .Select(h => new TransitHubResponse(
                h.Id,
                h.Name,
                h.Kind.ToString(),
                h.Location.Latitude,
                h.Location.Longitude,
                h.Address))
            .ToListAsync(cancellationToken);
    }
}

public sealed class GetTransitHubHandler : IRequestHandler<GetTransitHubQuery, TransitHubDetailResponse>
{
    private readonly IApplicationDbContext _context;

    public GetTransitHubHandler(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<TransitHubDetailResponse> Handle(GetTransitHubQuery request, CancellationToken cancellationToken)
    {
        var hub = await _context.TransitHubs
            .AsNoTracking()
            .FirstOrDefaultAsync(h => h.Id == request.HubId, cancellationToken)
            ?? throw new InvalidOperationException("Transit hub not found.");

        return new TransitHubDetailResponse(
            hub.Id,
            hub.Name,
            hub.Kind.ToString(),
            hub.Location.Latitude,
            hub.Location.Longitude,
            hub.Address,
            hub.IsActive);
    }
}

public sealed class ListUserTripsHandler : IRequestHandler<ListUserTripsQuery, IReadOnlyList<TransitTripResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserTripsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<TransitTripResponse>> Handle(ListUserTripsQuery request, CancellationToken cancellationToken)
    {
        // Always use the authenticated user's ID; ignore any client-provided UserId.
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");

        var query = _context.TransitTrips.AsNoTracking().Where(t => t.UserId == userId);
        if (request.Status.HasValue)
            query = query.Where(t => t.Status == request.Status.Value);

        if (_context.IsPostgreSQL)
        {
            return await query
                .Include(t => t.Hub)
                .OrderByDescending(t => t.CreatedAt)
                .Select(t => new TransitTripResponse(
                    t.Id,
                    t.Hub.Name,
                    t.ArrivalFrom,
                    t.ArrivalMode,
                    t.ArrivalAt,
                    t.PartySize,
                    t.DropOffLocation,
                    t.Status.ToString(),
                    t.Price,
                    t.PaymentStatus.ToString(),
                    t.CompletedAt))
                .ToListAsync(cancellationToken);
        }

        var trips = await query
            .Include(t => t.Hub)
            .ToListAsync(cancellationToken);

        return trips
            .OrderByDescending(t => t.CreatedAt)
            .Select(t => new TransitTripResponse(
                t.Id,
                t.Hub.Name,
                t.ArrivalFrom,
                t.ArrivalMode,
                t.ArrivalAt,
                t.PartySize,
                t.DropOffLocation,
                t.Status.ToString(),
                t.Price,
                t.PaymentStatus.ToString(),
                t.CompletedAt))
            .ToList();
    }
}