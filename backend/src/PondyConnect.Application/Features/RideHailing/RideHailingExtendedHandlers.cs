namespace PondyConnect.Application.Features.RideHailing;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

// === Saved Locations ===

public sealed record AddSavedLocationCommand(string Label, string Address, double Latitude, double Longitude) : IRequest<SavedLocationResponse>;
public sealed record UpdateSavedLocationCommand(Guid Id, string Label, string Address, double Latitude, double Longitude) : IRequest<Unit>;
public sealed record DeleteSavedLocationCommand(Guid Id) : IRequest<Unit>;
public sealed record ListSavedLocationsQuery : IRequest<IReadOnlyList<SavedLocationResponse>>;
public sealed record SavedLocationResponse(Guid Id, string Label, string Address, double Latitude, double Longitude);

public sealed class AddSavedLocationHandler : IRequestHandler<AddSavedLocationCommand, SavedLocationResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public AddSavedLocationHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<SavedLocationResponse> Handle(AddSavedLocationCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var location = GeoLocation.Create(request.Latitude, request.Longitude);
        var saved = SavedLocation.Create(userId, request.Label, request.Address, location);
        _context.SavedLocations.Add(saved);
        await _context.SaveChangesAsync(cancellationToken);
        return new SavedLocationResponse(saved.Id, saved.Label, saved.Address, saved.Location.Latitude, saved.Location.Longitude);
    }
}

public sealed class UpdateSavedLocationHandler : IRequestHandler<UpdateSavedLocationCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateSavedLocationHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(UpdateSavedLocationCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var saved = await _context.SavedLocations.FirstOrDefaultAsync(s => s.Id == request.Id && s.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Saved location not found.");
        saved.Update(request.Label, request.Address, GeoLocation.Create(request.Latitude, request.Longitude));
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed class DeleteSavedLocationHandler : IRequestHandler<DeleteSavedLocationCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DeleteSavedLocationHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(DeleteSavedLocationCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var saved = await _context.SavedLocations.FirstOrDefaultAsync(s => s.Id == request.Id && s.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Saved location not found.");
        _context.SavedLocations.Remove(saved);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed class ListSavedLocationsHandler : IRequestHandler<ListSavedLocationsQuery, IReadOnlyList<SavedLocationResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListSavedLocationsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<SavedLocationResponse>> Handle(ListSavedLocationsQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var locations = await _context.SavedLocations.AsNoTracking()
            .Where(s => s.UserId == userId)
            .ToListAsync(cancellationToken);
        // Sort on client side to avoid SQLite DateTimeOffset ORDER BY issues
        locations = locations.OrderByDescending(s => s.CreatedAt).ToList();
        return locations.Select(s => new SavedLocationResponse(s.Id, s.Label, s.Address, s.Location.Latitude, s.Location.Longitude)).ToList();
    }
}

// === Scheduled Rides ===

public sealed record ScheduleRideCommand(
    double PickupLatitude, double PickupLongitude, string PickupAddress,
    double DropoffLatitude, double DropoffLongitude, string DropoffAddress,
    double DistanceKm, int VehicleType, int PaymentMethod,
    DateTimeOffset ScheduledAt, decimal EstimatedFare) : IRequest<ScheduledRideResponse>;

public sealed record ScheduledRideResponse(
    Guid Id, string Status, string PickupAddress, string DropoffAddress,
    double DistanceKm, string VehicleType, string PaymentMethod,
    DateTimeOffset ScheduledAt, decimal EstimatedFare, Guid? ResultingRideId);

public sealed class ScheduleRideHandler : IRequestHandler<ScheduleRideCommand, ScheduledRideResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ScheduleRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<ScheduledRideResponse> Handle(ScheduleRideCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var scheduled = ScheduledRide.Create(
            userId,
            GeoLocation.Create(request.PickupLatitude, request.PickupLongitude),
            request.PickupAddress,
            GeoLocation.Create(request.DropoffLatitude, request.DropoffLongitude),
            request.DropoffAddress,
            request.DistanceKm,
            (VehicleType)request.VehicleType,
            (PaymentMethod)request.PaymentMethod,
            request.ScheduledAt,
            request.EstimatedFare);

        _context.ScheduledRides.Add(scheduled);
        await _context.SaveChangesAsync(cancellationToken);

        return new ScheduledRideResponse(
            scheduled.Id, scheduled.Status.ToString(), scheduled.PickupAddress,
            scheduled.DropoffAddress, scheduled.DistanceKm, scheduled.VehicleType.ToString(),
            scheduled.PaymentMethod.ToString(), scheduled.ScheduledAt, scheduled.EstimatedFare,
            scheduled.ResultingRideId);
    }
}

public sealed record ListScheduledRidesQuery : IRequest<IReadOnlyList<ScheduledRideResponse>>;
public sealed record CancelScheduledRideCommand(Guid Id) : IRequest<Unit>;

public sealed class ListScheduledRidesHandler : IRequestHandler<ListScheduledRidesQuery, IReadOnlyList<ScheduledRideResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListScheduledRidesHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<ScheduledRideResponse>> Handle(ListScheduledRidesQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var rides = await _context.ScheduledRides.AsNoTracking()
            .Where(s => s.UserId == userId)
            .ToListAsync(cancellationToken);
        // Filter by status and sort on client side to avoid SQLite enum/DateTimeOffset translation issues
        rides = rides.Where(s => s.Status == ScheduledRideStatus.Scheduled)
                     .OrderBy(s => s.ScheduledAt).ToList();
        return rides.Select(s => new ScheduledRideResponse(
            s.Id, s.Status.ToString(), s.PickupAddress, s.DropoffAddress,
            s.DistanceKm, s.VehicleType.ToString(), s.PaymentMethod.ToString(),
            s.ScheduledAt, s.EstimatedFare, s.ResultingRideId)).ToList();
    }
}

public sealed class CancelScheduledRideHandler : IRequestHandler<CancelScheduledRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CancelScheduledRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(CancelScheduledRideCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var scheduled = await _context.ScheduledRides.FirstOrDefaultAsync(s => s.Id == request.Id && s.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Scheduled ride not found.");
        scheduled.Cancel();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// === Driver Earnings ===

public sealed record GetDriverEarningsQuery(DateTimeOffset? From = null, DateTimeOffset? To = null) : IRequest<DriverEarningsResponse>;

public sealed record DriverEarningsResponse(
    decimal TodayEarnings,
    decimal WeekEarnings,
    decimal MonthEarnings,
    int TodayRides,
    int WeekRides,
    int MonthRides,
    decimal AvgRating,
    double OnlineHoursToday,
    List<DriverEarningBreakdown> RecentRides);

public sealed record DriverEarningBreakdown(
    Guid RideId, DateTimeOffset CompletedAt, decimal Earnings, double DistanceKm, int DurationMin, string Status);

public sealed class GetDriverEarningsHandler : IRequestHandler<GetDriverEarningsQuery, DriverEarningsResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetDriverEarningsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DriverEarningsResponse> Handle(GetDriverEarningsQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var driver = await _context.Drivers.AsNoTracking().FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Driver profile not found.");

        var now = DateTimeOffset.UtcNow;
        var todayStart = new DateTimeOffset(now.Date, TimeSpan.Zero);
        var weekStart = todayStart.AddDays(-7);
        var monthStart = todayStart.AddDays(-30);

        // Split query: server-side filter on translatable fields, client-side filter on enum and sort
        var completedRidesRaw = await _context.RideRequests.AsNoTracking()
            .Where(r => r.DriverId == driver.Id && r.CompletedAt != null)
            .ToListAsync(cancellationToken);
        var completedRides = completedRidesRaw
            .Where(r => r.Status == RideStatus.Completed)
            .OrderByDescending(r => r.CompletedAt)
            .Take(50)
            .ToList();

        var todayRides = completedRides.Where(r => r.CompletedAt >= todayStart).ToList();
        var weekRides = completedRides.Where(r => r.CompletedAt >= weekStart).ToList();
        var monthRides = completedRides.Where(r => r.CompletedAt >= monthStart).ToList();

        var todayEarnings = todayRides.Sum(r => r.IsSos ? r.SosDriverPayout : r.Fare);
        var weekEarnings = weekRides.Sum(r => r.IsSos ? r.SosDriverPayout : r.Fare);
        var monthEarnings = monthRides.Sum(r => r.IsSos ? r.SosDriverPayout : r.Fare);

        var recentBreakdown = completedRides.Take(10).Select(r => new DriverEarningBreakdown(
            r.Id, r.CompletedAt!.Value, r.IsSos ? r.SosDriverPayout : r.Fare,
            r.ActualDistanceKm ?? r.DistanceKm, r.ActualDurationMin ?? r.EstimatedDurationMin,
            r.Status.ToString())).ToList();

        return new DriverEarningsResponse(
            todayEarnings, weekEarnings, monthEarnings,
            todayRides.Count, weekRides.Count, monthRides.Count,
            (decimal)driver.Rating, 0, recentBreakdown);
    }
}

// === Driver Reassignment ===

public sealed record ReassignRideCommand(Guid RideId) : IRequest<Unit>;

public sealed class ReassignRideHandler : IRequestHandler<ReassignRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;

    public ReassignRideHandler(IApplicationDbContext context) => _context = context;

    public async Task<Unit> Handle(ReassignRideCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        if (ride.Status != RideStatus.DriverCancelled && ride.Status != RideStatus.NoDriversAvailable)
            throw new InvalidOperationException("Only driver-cancelled or no-drivers-available rides can be reassigned.");

        ride.ReassignForDispatch();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// === Get Ride Events (for timeline/history detail) ===

public sealed record GetRideEventsQuery(Guid RideId) : IRequest<IReadOnlyList<RideEventResponse>>;

public sealed record RideEventResponse(
    Guid Id, string EventType, DateTimeOffset Timestamp, string? ActorUserId, string? Metadata);

public sealed class GetRideEventsHandler : IRequestHandler<GetRideEventsQuery, IReadOnlyList<RideEventResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetRideEventsHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<RideEventResponse>> Handle(GetRideEventsQuery request, CancellationToken cancellationToken)
    {
        var events = await _context.RideEvents.AsNoTracking()
            .Where(e => e.RideId == request.RideId)
            .ToListAsync(cancellationToken);

        // Sort on client side to avoid SQLite DateTimeOffset ORDER BY issues
        events = events.OrderBy(e => e.Timestamp).ToList();

        return events.Select(e => new RideEventResponse(
            e.Id, e.EventType.ToString(), e.Timestamp, e.ActorUserId?.ToString(), e.Metadata)).ToList();
    }
}

// === Validators ===

public sealed class AddSavedLocationValidator : AbstractValidator<AddSavedLocationCommand>
{
    public AddSavedLocationValidator()
    {
        RuleFor(x => x.Label).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Address).NotEmpty().MaximumLength(300);
        RuleFor(x => x.Latitude).InclusiveBetween(-90.0, 90.0);
        RuleFor(x => x.Longitude).InclusiveBetween(-180.0, 180.0);
    }
}

public sealed class ScheduleRideValidator : AbstractValidator<ScheduleRideCommand>
{
    public ScheduleRideValidator()
    {
        RuleFor(x => x.PickupAddress).NotEmpty().MaximumLength(300);
        RuleFor(x => x.DropoffAddress).NotEmpty().MaximumLength(300);
        RuleFor(x => x.DistanceKm).GreaterThan(0);
        RuleFor(x => x.VehicleType).InclusiveBetween(1, 3);
        RuleFor(x => x.PaymentMethod).InclusiveBetween(1, 3);
        RuleFor(x => x.ScheduledAt).Must(s => s > DateTimeOffset.UtcNow.AddMinutes(15))
            .WithMessage("Scheduled time must be at least 15 minutes in the future.");
    }
}
