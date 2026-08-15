namespace PondyConnect.Application.Features.RideHailing;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Application.Features.GeoFence;

public sealed record RequestRideCommand(
    double PickupLatitude,
    double PickupLongitude,
    string PickupAddress,
    double DropoffLatitude,
    double DropoffLongitude,
    string DropoffAddress,
    double DistanceKm,
    VehicleType VehicleType,
    PaymentMethod PaymentMethod,
    bool IsSosRequest = false) : IRequest<RideRequestResponse>;

public sealed record RideRequestResponse(
    Guid RideId,
    double DistanceKm,
    int EstimatedDurationMin,
    decimal Fare,
    decimal DriverEarnings,
    decimal PlatformBookingFee,
    decimal TotalAmount,
    string Status,
    string VehicleType,
    string PaymentMethod);

public sealed class RequestRideValidator : AbstractValidator<RequestRideCommand>
{
    public RequestRideValidator()
    {
        RuleFor(x => x.PickupAddress).NotEmpty().MaximumLength(300);
        RuleFor(x => x.DropoffAddress).NotEmpty().MaximumLength(300);
        RuleFor(x => x.DistanceKm).GreaterThan(0);
        RuleFor(x => x.PickupLatitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.DropoffLatitude).InclusiveBetween(-90, 90);
        RuleFor(x => x.VehicleType).IsInEnum().Must(v => (int)v >= 1).WithMessage("VehicleType must be a valid value (Bike=1, Auto=2, Car=3).");
        RuleFor(x => x.PaymentMethod).IsInEnum().Must(p => (int)p >= 1).WithMessage("PaymentMethod must be a valid value (Cash=1, UPI=2, Card=3).");
    }
}

public sealed class RequestRideHandler : IRequestHandler<RequestRideCommand, RideRequestResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ServiceAreaValidator _serviceArea;
    private readonly SurgeCalculator _surgeCalculator;
    private readonly IRoutingService? _routingService;

    public RequestRideHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        ServiceAreaValidator serviceArea,
        SurgeCalculator surgeCalculator,
        IRoutingService? routingService = null)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
        _surgeCalculator = surgeCalculator;
        _routingService = routingService;
    }

    public async Task<RideRequestResponse> Handle(RequestRideCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        // Prevent multiple active rides for the same consumer
        var hasActiveRide = await _context.RideRequests.AsNoTracking()
            .AnyAsync(r => r.UserId == userId
                && (r.Status == RideStatus.Requested
                    || r.Status == RideStatus.Searching
                    || r.Status == RideStatus.DriverAssigned
                    || r.Status == RideStatus.Accepted
                    || r.Status == RideStatus.ArrivedAtPickup
                    || r.Status == RideStatus.EnRoute), cancellationToken);

        if (hasActiveRide)
            throw new InvalidOperationException("You already have an active ride. Cancel it before requesting a new one.");

        var pickup = GeoLocation.Create(request.PickupLatitude, request.PickupLongitude);
        var dropoff = GeoLocation.Create(request.DropoffLatitude, request.DropoffLongitude);

        _serviceArea.EnsureWithinZone(pickup);
        _serviceArea.EnsureWithinZone(dropoff);

        // Validate distance via routing service when available.
        // Server-computed road distance takes precedence over client-provided value
        // to prevent fare manipulation.
        var validatedDistanceKm = request.DistanceKm;
        var validatedDurationMin = 0;

        if (_routingService is not null)
        {
            var route = await _routingService.GetRouteAsync(
                request.PickupLatitude, request.PickupLongitude,
                request.DropoffLatitude, request.DropoffLongitude,
                cancellationToken);

            if (route is not null)
            {
                // Use server-validated distance and duration
                validatedDistanceKm = route.DistanceKm;
                validatedDurationMin = route.DurationMin;
            }
            else
            {
                // Fallback: sanity-check client distance against straight-line distance
                var straightLineKm = pickup.DistanceKm(dropoff);
                // Reject if client claims more than 3x the straight-line distance (impossible road detour)
                if (request.DistanceKm > straightLineKm * 3 + 1)
                    throw new ArgumentException("Reported distance is implausibly large for the given coordinates.");
            }
        }

        var duration = validatedDurationMin > 0
            ? validatedDurationMin
            : RidePricingService.EstimateDurationMin(validatedDistanceKm, request.VehicleType);

        // Calculate surge (skip for SOS requests — emergency rides always flat surge pricing)
        decimal surgeMultiplier = 1.0m;
        string? surgeReason = null;
        if (!request.IsSosRequest)
        {
            (surgeMultiplier, surgeReason) = await _surgeCalculator.CalculateSurgeAsync(pickup, request.VehicleType, cancellationToken);
        }

        var pricing = RidePricingService.CalculateFareWithSurge(
            validatedDistanceKm, duration, request.VehicleType, surgeMultiplier, surgeReason);

        decimal fare = pricing.Fare;
        bool isSos = request.IsSosRequest;
        decimal sosDriverPayout = 0m;
        decimal platformEmergencyFee = 0m;

        if (isSos)
        {
            var sosPricing = RidePricingService.CalculateSosFare(pricing.Fare);
            fare = sosPricing.GrossSosFare;
            sosDriverPayout = sosPricing.DriverPayout;
            platformEmergencyFee = sosPricing.PlatformEmergencyFee;
        }

        var ride = RideRequest.Create(
            userId: userId,
            pickupLocation: pickup,
            pickupAddress: request.PickupAddress,
            dropoffLocation: dropoff,
            dropoffAddress: request.DropoffAddress,
            distanceKm: validatedDistanceKm,
            estimatedDurationMin: duration,
            vehicleType: request.VehicleType,
            fare: fare,
            paymentMethod: request.PaymentMethod,
            isSos: isSos,
            sosDriverPayout: sosDriverPayout,
            platformEmergencyFee: platformEmergencyFee,
            surgeMultiplier: surgeMultiplier,
            surgeReason: surgeReason,
            baseFare: pricing.BaseFare,
            distanceFare: pricing.DistanceFare,
            timeFare: pricing.TimeFare);

        _context.RideRequests.Add(ride);
        await _context.SaveChangesAsync(cancellationToken);

        var driverEarnings = isSos ? sosDriverPayout : ride.Fare;

        return new RideRequestResponse(
            ride.Id, ride.DistanceKm, ride.EstimatedDurationMin, ride.Fare,
            driverEarnings, ride.PlatformBookingFee, ride.TotalAmount, ride.Status.ToString(),
            ride.VehicleType.ToString(), ride.PaymentMethod.ToString());
    }
}

public sealed record AcceptRideCommand(Guid RideId) : IRequest<RideRequestResponse>;

public sealed class AcceptRideHandler : IRequestHandler<AcceptRideCommand, RideRequestResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public AcceptRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<RideRequestResponse> Handle(AcceptRideCommand request, CancellationToken cancellationToken)
    {
        var driverId = await ResolveDriverIdAsync(cancellationToken)
            ?? throw new UnauthorizedAccessException("Driver profile not found.");

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == driverId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Driver profile not found.");

        if (driver.IsOnRide)
            throw new InvalidOperationException("Cannot accept a new ride while already on an active ride.");

        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        ride.Accept(driverId);

        driver.StartRide(ride.Id);

        await _context.SaveChangesAsync(cancellationToken);

        return new RideRequestResponse(
            ride.Id, ride.DistanceKm, ride.EstimatedDurationMin, ride.Fare,
            ride.Fare, ride.PlatformBookingFee, ride.TotalAmount, ride.Status.ToString(),
            ride.VehicleType.ToString(), ride.PaymentMethod.ToString());
    }

    private async Task<Guid?> ResolveDriverIdAsync(CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId;
        if (userId == null) return null;

        return await _context.Drivers.AsNoTracking()
            .Where(d => d.UserId == userId && d.IsApproved)
            .Select(d => d.Id)
            .FirstOrDefaultAsync(cancellationToken);
    }
}

public sealed record StartRideCommand(Guid RideId) : IRequest<Unit>;
public sealed record CompleteRideCommand(Guid RideId) : IRequest<Unit>;
public sealed record CancelRideCommand(Guid RideId, string? Reason = null) : IRequest<Unit>;

public sealed class StartRideHandler : IRequestHandler<StartRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public StartRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(StartRideCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        await ValidateDriverOwnershipAsync(ride, cancellationToken);
        ride.StartRide();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task ValidateDriverOwnershipAsync(Domain.Entities.RideRequest ride, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (!ride.DriverId.HasValue) return;
        var isAssigned = await _context.Drivers.AsNoTracking()
            .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
        if (!isAssigned)
            throw new UnauthorizedAccessException("Only the assigned driver can perform this action.");
    }
}

public sealed class CompleteRideHandler : IRequestHandler<CompleteRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CompleteRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(CompleteRideCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        await ValidateDriverOwnershipAsync(ride, cancellationToken);
        ride.Complete();

        // Clear the driver's active ride state so they can accept new rides
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            driver?.EndRide();
        }

        // Log ride event for audit trail
        _context.RideEvents.Add(RideEvent.Create(ride.Id, RideEventType.Completed, ride.DriverId));

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task ValidateDriverOwnershipAsync(Domain.Entities.RideRequest ride, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (!ride.DriverId.HasValue) return;
        var isAssigned = await _context.Drivers.AsNoTracking()
            .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
        if (!isAssigned)
            throw new UnauthorizedAccessException("Only the assigned driver can perform this action.");
    }
}

public sealed class CancelRideHandler : IRequestHandler<CancelRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CancelRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(CancelRideCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        await ValidateRiderOrDriverOwnershipAsync(ride, cancellationToken);
        ride.Cancel(request.Reason);

        // Clear the driver's active ride state if a driver was assigned
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            driver?.EndRide();
        }

        // Log ride event for audit trail
        _context.RideEvents.Add(RideEvent.Create(ride.Id, RideEventType.Cancelled, metadata: request.Reason));

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task ValidateRiderOrDriverOwnershipAsync(Domain.Entities.RideRequest ride, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        var isRider = ride.UserId == userId;
        var isDriver = ride.DriverId.HasValue
            && await _context.Drivers.AsNoTracking()
                .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
        if (!isRider && !isDriver)
            throw new UnauthorizedAccessException("Only the rider or assigned driver can cancel this ride.");
    }
}

public sealed record GetRideQuery(Guid RideId) : IRequest<RideDetailResponse>;

public sealed record RideDetailResponse(
    Guid Id,
    string PickupAddress,
    string DropoffAddress,
    double PickupLat,
    double PickupLng,
    double DropoffLat,
    double DropoffLng,
    double DistanceKm,
    int EstimatedDurationMin,
    string VehicleType,
    decimal Fare,
    decimal DriverEarnings,
    decimal PlatformBookingFee,
    decimal TotalAmount,
    string PaymentMethod,
    string Status,
    DateTimeOffset RequestedAt,
    DateTimeOffset? AcceptedAt,
    DateTimeOffset? CompletedAt,
    Guid? DriverId);

public sealed class GetRideHandler : IRequestHandler<GetRideQuery, RideDetailResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<RideDetailResponse> Handle(GetRideQuery request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.AsNoTracking().FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        // Authorization: only the rider, the assigned driver, or an admin can view ride details.
        var userId = _currentUser.UserId;
        var isAdmin = string.Equals(_currentUser.Role, "Admin", StringComparison.OrdinalIgnoreCase);
        if (!isAdmin && userId.HasValue)
        {
            var isRider = ride.UserId == userId;
            var isDriver = false;
            if (ride.DriverId.HasValue)
            {
                isDriver = await _context.Drivers
                    .AsNoTracking()
                    .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            }
            if (!isRider && !isDriver)
                throw new UnauthorizedAccessException("You are not authorized to view this ride.");
        }

        return new RideDetailResponse(
            ride.Id, ride.PickupAddress, ride.DropoffAddress,
            ride.PickupLocation.Latitude, ride.PickupLocation.Longitude,
            ride.DropoffLocation.Latitude, ride.DropoffLocation.Longitude,
            ride.DistanceKm,
            ride.EstimatedDurationMin, ride.VehicleType.ToString(), ride.Fare,
            ride.Fare, ride.PlatformBookingFee, ride.TotalAmount, ride.PaymentMethod.ToString(),
            ride.Status.ToString(), ride.RequestedAt, ride.AcceptedAt, ride.CompletedAt, ride.DriverId);
    }
}

/// <summary>
/// Testing helper: returns the ride-start OTP for a given ride.
/// Only available when the OTP service is in test/mock mode.
/// Authorization: the rider or the assigned driver can peek.
/// </summary>
public sealed record PeekRideOtpQuery(Guid RideId) : IRequest<PeekRideOtpResponse>;

public sealed record PeekRideOtpResponse(string? Otp);

public sealed class PeekRideOtpHandler : IRequestHandler<PeekRideOtpQuery, PeekRideOtpResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public PeekRideOtpHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<PeekRideOtpResponse> Handle(PeekRideOtpQuery request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.AsNoTracking().FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        // Authorization: only the rider, the assigned driver, or an admin can peek.
        var userId = _currentUser.UserId;
        var isAdmin = string.Equals(_currentUser.Role, "Admin", StringComparison.OrdinalIgnoreCase);
        if (!isAdmin && userId.HasValue)
        {
            var isRider = ride.UserId == userId;
            var isDriver = false;
            if (ride.DriverId.HasValue)
            {
                isDriver = await _context.Drivers
                    .AsNoTracking()
                    .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            }
            if (!isRider && !isDriver)
                throw new UnauthorizedAccessException("You are not authorized to view this ride.");
        }

        return new PeekRideOtpResponse(ride.OtpCode);
    }
}

public sealed record ListUserRidesQuery(int Page = 1, int PageSize = 20) : IRequest<IReadOnlyList<RideSummaryResponse>>;

public sealed record RideSummaryResponse(Guid Id, string Status, decimal TotalAmount, DateTimeOffset RequestedAt, string PickupAddress, string DropoffAddress);

public sealed class ListUserRidesHandler : IRequestHandler<ListUserRidesQuery, IReadOnlyList<RideSummaryResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListUserRidesHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<RideSummaryResponse>> Handle(ListUserRidesQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var rides = await _context.RideRequests.AsNoTracking()
            .Where(r => r.UserId == userId)
            .ToListAsync(cancellationToken);

        return rides
            .OrderByDescending(r => r.RequestedAt)
            .Skip((request.Page - 1) * request.PageSize)
            .Take(request.PageSize)
            .Select(r => new RideSummaryResponse(r.Id, r.Status.ToString(), r.TotalAmount, r.RequestedAt, r.PickupAddress, r.DropoffAddress))
            .ToList();
    }
}

public sealed record GetNearbyDriversQuery(double Latitude, double Longitude, double RadiusKm = 3.0) : IRequest<IReadOnlyList<NearbyDriverResponse>>;

public sealed record NearbyDriverResponse(Guid Id, string Name, string VehicleType, double DistanceKm, double Rating, int TotalRides);

public sealed class GetNearbyDriversHandler : IRequestHandler<GetNearbyDriversQuery, IReadOnlyList<NearbyDriverResponse>>
{
    private readonly IApplicationDbContext _context;

    public GetNearbyDriversHandler(IApplicationDbContext context) => _context = context;

    public async Task<IReadOnlyList<NearbyDriverResponse>> Handle(GetNearbyDriversQuery request, CancellationToken cancellationToken)
    {
        var center = GeoLocation.Create(request.Latitude, request.Longitude);

        var drivers = await _context.Drivers.AsNoTracking()
            .Where(d => d.IsOnline && d.IsApproved)
            .ToListAsync(cancellationToken);

        return drivers
            .Select(d => new { Driver = d, Distance = d.CurrentLocation.DistanceKm(center) })
            .Where(x => x.Distance <= request.RadiusKm)
            .OrderBy(x => x.Distance)
            .Select(x => new NearbyDriverResponse(x.Driver.Id, x.Driver.Name, x.Driver.VehicleType.ToString(), x.Distance, x.Driver.Rating, x.Driver.TotalRides))
            .ToList();
    }
}

public sealed record RegisterDriverCommand(string Name, string Phone, VehicleType VehicleType, string? VehiclePlate = null) : IRequest<DriverResponse>;

public sealed record DriverResponse(Guid Id, string Name, string Phone, string VehicleType, string? VehiclePlate, bool IsApproved, bool IsOnline, double Rating, int TotalRides);

public sealed class RegisterDriverHandler : IRequestHandler<RegisterDriverCommand, DriverResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public RegisterDriverHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<DriverResponse> Handle(RegisterDriverCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = Driver.Create(userId, request.Name, request.Phone, request.VehicleType, request.VehiclePlate);
        _context.Drivers.Add(driver);
        await _context.SaveChangesAsync(cancellationToken);

        return new DriverResponse(driver.Id, driver.Name, driver.Phone, driver.VehicleType.ToString(), driver.VehiclePlate, driver.IsApproved, driver.IsOnline, driver.Rating, driver.TotalRides);
    }
}

public sealed record ToggleDriverOnlineCommand(bool GoOnline) : IRequest<Unit>;
public sealed record UpdateDriverLocationCommand(double Latitude, double Longitude) : IRequest<Unit>;

public sealed class ToggleDriverOnlineHandler : IRequestHandler<ToggleDriverOnlineCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ToggleDriverOnlineHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(ToggleDriverOnlineCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Driver profile not found.");

        if (request.GoOnline) driver.GoOnline();
        else driver.GoOffline();

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed class UpdateDriverLocationHandler : IRequestHandler<UpdateDriverLocationCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public UpdateDriverLocationHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(UpdateDriverLocationCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Driver profile not found.");

        driver.UpdateLocation(GeoLocation.Create(request.Latitude, request.Longitude));
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

// === Phase 2+ new handlers: ride lifecycle, OTP, ratings, cancellation, safety ===

public sealed record ArriveAtPickupCommand(Guid RideId) : IRequest<Unit>;

public sealed class ArriveAtPickupHandler : IRequestHandler<ArriveAtPickupCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ArriveAtPickupHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(ArriveAtPickupCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        await ValidateDriverOwnershipAsync(ride, cancellationToken);
        ride.ArriveAtPickup();
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }

    private async Task ValidateDriverOwnershipAsync(Domain.Entities.RideRequest ride, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (!ride.DriverId.HasValue) return;
        var isAssigned = await _context.Drivers.AsNoTracking()
            .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
        if (!isAssigned)
            throw new UnauthorizedAccessException("Only the assigned driver can perform this action.");
    }
}

public sealed record VerifyOtpAndStartCommand(Guid RideId, string Otp) : IRequest<Unit>;

public sealed class VerifyOtpAndStartHandler : IRequestHandler<VerifyOtpAndStartCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public VerifyOtpAndStartHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(VerifyOtpAndStartCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.DriverId.HasValue)
        {
            var isAssigned = await _context.Drivers.AsNoTracking()
                .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            if (!isAssigned)
                throw new UnauthorizedAccessException("Only the assigned driver can start this ride.");
        }

        ride.VerifyOtpAndStart(request.Otp);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record CompleteRideWithMetricsCommand(Guid RideId, double ActualDistanceKm, int ActualDurationMin) : IRequest<Unit>;

public sealed class CompleteRideWithMetricsHandler : IRequestHandler<CompleteRideWithMetricsCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CompleteRideWithMetricsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(CompleteRideWithMetricsCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.DriverId.HasValue)
        {
            var isAssigned = await _context.Drivers.AsNoTracking()
                .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            if (!isAssigned)
                throw new UnauthorizedAccessException("Only the assigned driver can complete this ride.");
        }

        ride.CompleteWithMetrics(request.ActualDistanceKm, request.ActualDurationMin);

        // End the driver's ride state
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            if (driver != null)
            {
                driver.EndRide();
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record CancelRideByRiderCommand(Guid RideId, string? Reason = null) : IRequest<CancelRideResponse>;

public sealed record CancelRideResponse(decimal CancellationFee, string Status);

public sealed class CancelRideByRiderHandler : IRequestHandler<CancelRideByRiderCommand, CancelRideResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CancelRideByRiderHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<CancelRideResponse> Handle(CancelRideByRiderCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.UserId != userId)
            throw new UnauthorizedAccessException("Only the rider who booked this ride can cancel it.");

        var fee = ride.CalculateCancellationFee();
        ride.CancelByRider(request.Reason);

        // Free the driver if one was assigned
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            if (driver != null && driver.IsOnRide)
            {
                driver.EndRide();
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return new CancelRideResponse(fee, ride.Status.ToString());
    }
}

public sealed record CancelRideByDriverCommand(Guid RideId, string? Reason = null) : IRequest<Unit>;

public sealed class CancelRideByDriverHandler : IRequestHandler<CancelRideByDriverCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public CancelRideByDriverHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(CancelRideByDriverCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.DriverId.HasValue)
        {
            var isAssigned = await _context.Drivers.AsNoTracking()
                .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            if (!isAssigned)
                throw new UnauthorizedAccessException("Only the assigned driver can cancel this ride.");
        }

        ride.CancelByDriver(request.Reason);

        // Record driver cancellation and free the driver
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            if (driver != null)
            {
                driver.RecordCancellation();
                if (driver.IsOnRide)
                    driver.EndRide();
            }
        }

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record RateRideCommand(Guid RideId, int Rating, string? Feedback = null, bool ByDriver = false) : IRequest<Unit>;

public sealed class RateRideHandler : IRequestHandler<RateRideCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public RateRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(RateRideCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        // Determine the actual role from the JWT token, not the request body
        var isDriver = string.Equals(_currentUser.Role, "Driver", StringComparison.OrdinalIgnoreCase);

        // Ownership check: only the rider who booked the ride or the assigned driver can rate
        var userId = _currentUser.UserId;
        if (userId is null)
            throw new UnauthorizedAccessException("User not authenticated.");

        if (isDriver)
        {
            // Driver can only rate if they were assigned to this ride
            var driver = await _context.Drivers.AsNoTracking()
                .FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken);

            if (driver is null || ride.DriverId is null || ride.DriverId != driver.Id)
                throw new InvalidOperationException("Only the assigned driver can rate this ride.");

            // Prevent duplicate driver rating
            if (ride.RatingByDriver.HasValue)
                throw new InvalidOperationException("Driver has already rated this ride.");

            ride.RateByDriver(request.Rating, request.Feedback);
        }
        else
        {
            // Rider can only rate their own ride
            if (ride.UserId != userId)
                throw new InvalidOperationException("Only the rider who booked this ride can rate it.");

            // Prevent duplicate rider rating
            if (ride.RatingByRider.HasValue)
                throw new InvalidOperationException("Rider has already rated this ride.");

            ride.RateByRider(request.Rating, request.Feedback);

            // Update driver's overall rating
            if (ride.DriverId.HasValue)
            {
                var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
                if (driver != null)
                {
                    driver.UpdateRating(request.Rating);
                }
            }
        }

        // Log ride event
        _context.RideEvents.Add(RideEvent.Create(ride.Id, RideEventType.RatingSubmitted, userId));

        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record EnableTripSharingCommand(Guid RideId) : IRequest<TripShareResponse>;

public sealed record TripShareResponse(Guid TripShareToken, string ShareUrl);

public sealed class EnableTripSharingHandler : IRequestHandler<EnableTripSharingCommand, TripShareResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public EnableTripSharingHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<TripShareResponse> Handle(EnableTripSharingCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.UserId != userId)
            throw new UnauthorizedAccessException("Only the rider who booked this ride can enable trip sharing.");

        var token = ride.EnableTripSharing();
        await _context.SaveChangesAsync(cancellationToken);

        return new TripShareResponse(token, $"/trip/{token}");
    }
}

public sealed record GetTripShareQuery(Guid TripShareToken) : IRequest<TripShareDetailResponse>;

public sealed record TripShareDetailResponse(
    Guid RideId,
    string Status,
    string PickupAddress,
    string DropoffAddress,
    string? DriverName,
    string? VehicleType,
    string? VehiclePlate,
    double? DriverLatitude,
    double? DriverLongitude,
    double? DriverRating,
    DateTimeOffset RequestedAt);

public sealed class GetTripShareHandler : IRequestHandler<GetTripShareQuery, TripShareDetailResponse>
{
    private readonly IApplicationDbContext _context;

    public GetTripShareHandler(IApplicationDbContext context) => _context = context;

    public async Task<TripShareDetailResponse> Handle(GetTripShareQuery request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.TripShareToken == request.TripShareToken, cancellationToken)
            ?? throw new InvalidOperationException("Trip not found or sharing disabled.");

        Driver? driver = null;
        if (ride.DriverId.HasValue)
        {
            driver = await _context.Drivers.AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
        }

        return new TripShareDetailResponse(
            ride.Id,
            ride.Status.ToString(),
            ride.PickupAddress,
            ride.DropoffAddress,
            driver?.Name,
            ride.VehicleType.ToString(),
            driver?.VehiclePlate,
            driver?.CurrentLocation.Latitude,
            driver?.CurrentLocation.Longitude,
            driver?.Rating,
            ride.RequestedAt);
    }
}

public sealed record TriggerSosCommand(Guid RideId, double Latitude, double Longitude) : IRequest<SosAlertResponse>;

public sealed record SosAlertResponse(Guid SosAlertId, Guid RideId, string Status);

public sealed class TriggerSosHandler : IRequestHandler<TriggerSosCommand, SosAlertResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<TriggerSosHandler> _logger;

    public TriggerSosHandler(IApplicationDbContext context, ICurrentUserService currentUser, ILogger<TriggerSosHandler> logger)
    {
        _context = context;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<SosAlertResponse> Handle(TriggerSosCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var ride = await _context.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        if (ride.UserId != userId)
            throw new UnauthorizedAccessException("Only the rider who booked this ride can trigger SOS.");

        var location = GeoLocation.Create(request.Latitude, request.Longitude);
        var alert = SosAlert.Create(ride.Id, userId, location);

        _logger.LogWarning("SOS triggered by user {UserId} for ride {RideId} at {Lat},{Lng}", userId, ride.Id, request.Latitude, request.Longitude);

        _context.SosAlerts.Add(alert);
        await _context.SaveChangesAsync(cancellationToken);

        return new SosAlertResponse(alert.Id, alert.RideId, alert.Status.ToString());
    }
}

public sealed record AddEmergencyContactCommand(string Name, string Phone, string? Relationship = null) : IRequest<EmergencyContactResponse>;

public sealed record EmergencyContactResponse(Guid Id, string Name, string Phone, string? Relationship);

public sealed class AddEmergencyContactHandler : IRequestHandler<AddEmergencyContactCommand, EmergencyContactResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public AddEmergencyContactHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<EmergencyContactResponse> Handle(AddEmergencyContactCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var contact = EmergencyContact.Create(userId, request.Name, request.Phone, request.Relationship);
        _context.EmergencyContacts.Add(contact);
        await _context.SaveChangesAsync(cancellationToken);

        return new EmergencyContactResponse(contact.Id, contact.Name, contact.Phone, contact.Relationship);
    }
}

public sealed record ListEmergencyContactsQuery : IRequest<IReadOnlyList<EmergencyContactResponse>>;

public sealed class ListEmergencyContactsHandler : IRequestHandler<ListEmergencyContactsQuery, IReadOnlyList<EmergencyContactResponse>>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public ListEmergencyContactsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<IReadOnlyList<EmergencyContactResponse>> Handle(ListEmergencyContactsQuery request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var contacts = await _context.EmergencyContacts.AsNoTracking()
            .Where(c => c.UserId == userId)
            .ToListAsync(cancellationToken);

        return contacts
            .Select(c => new EmergencyContactResponse(c.Id, c.Name, c.Phone, c.Relationship))
            .ToList();
    }
}

public sealed record DeleteEmergencyContactCommand(Guid ContactId) : IRequest<Unit>;

public sealed class DeleteEmergencyContactHandler : IRequestHandler<DeleteEmergencyContactCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public DeleteEmergencyContactHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<Unit> Handle(DeleteEmergencyContactCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var contact = await _context.EmergencyContacts
            .FirstOrDefaultAsync(c => c.Id == request.ContactId && c.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Emergency contact not found.");

        _context.EmergencyContacts.Remove(contact);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record ResolveSosCommand(Guid RideId) : IRequest<Unit>;

public sealed class ResolveSosHandler : IRequestHandler<ResolveSosCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly ILogger<ResolveSosHandler> _logger;

    public ResolveSosHandler(IApplicationDbContext context, ICurrentUserService currentUser, ILogger<ResolveSosHandler> logger)
    {
        _context = context;
        _currentUser = currentUser;
        _logger = logger;
    }

    public async Task<Unit> Handle(ResolveSosCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");
        var isAdmin = string.Equals(_currentUser.Role, "Admin", StringComparison.OrdinalIgnoreCase);

        var alert = await _context.SosAlerts
            .FirstOrDefaultAsync(s => s.RideId == request.RideId && s.Status == SosStatus.Active, cancellationToken)
            ?? throw new InvalidOperationException("No active SOS alert found for this ride.");

        // Only the rider who triggered the SOS or an admin can resolve it.
        if (!isAdmin)
        {
            var ride = await _context.RideRequests.AsNoTracking()
                .FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken);
            if (ride is null || ride.UserId != userId)
                throw new UnauthorizedAccessException("Only the rider or an admin can resolve this SOS.");
        }

        alert.Resolve(userId);
        _logger.LogWarning("SOS resolved for ride {RideId} by user {UserId}", request.RideId, userId);
        await _context.SaveChangesAsync(cancellationToken);
        return Unit.Value;
    }
}

public sealed record GetRideReceiptQuery(Guid RideId) : IRequest<RideReceiptResponse>;

public sealed record RideReceiptResponse(
    Guid RideId,
    string Status,
    string VehicleType,
    string PaymentMethod,
    decimal BaseFare,
    decimal DistanceFare,
    decimal TimeFare,
    decimal SurgeMultiplier,
    string? SurgeReason,
    decimal Fare,
    decimal PlatformBookingFee,
    decimal CancellationFee,
    decimal TotalAmount,
    double DistanceKm,
    double? ActualDistanceKm,
    int EstimatedDurationMin,
    int? ActualDurationMin,
    DateTimeOffset RequestedAt,
    DateTimeOffset? CompletedAt,
    string? PickupAddress,
    string? DropoffAddress,
    string? DriverName,
    int? RatingByRider);

public sealed class GetRideReceiptHandler : IRequestHandler<GetRideReceiptQuery, RideReceiptResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;

    public GetRideReceiptHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
    }

    public async Task<RideReceiptResponse> Handle(GetRideReceiptQuery request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        // Authorization: only the rider, the assigned driver, or an admin can view the receipt.
        var userId = _currentUser.UserId;
        var isAdmin = string.Equals(_currentUser.Role, "Admin", StringComparison.OrdinalIgnoreCase);
        if (!isAdmin && userId.HasValue)
        {
            var isRider = ride.UserId == userId;
            var isDriver = ride.DriverId.HasValue
                && await _context.Drivers.AsNoTracking()
                    .AnyAsync(d => d.Id == ride.DriverId.Value && d.UserId == userId, cancellationToken);
            if (!isRider && !isDriver)
                throw new UnauthorizedAccessException("You are not authorized to view this receipt.");
        }

        Driver? driver = null;
        if (ride.DriverId.HasValue)
        {
            driver = await _context.Drivers.AsNoTracking()
                .FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
        }

        return new RideReceiptResponse(
            ride.Id,
            ride.Status.ToString(),
            ride.VehicleType.ToString(),
            ride.PaymentMethod.ToString(),
            ride.BaseFare,
            ride.DistanceFare,
            ride.TimeFare,
            ride.SurgeMultiplier,
            ride.SurgeReason,
            ride.Fare,
            ride.PlatformBookingFee,
            ride.CancellationFee,
            ride.TotalAmount,
            ride.DistanceKm,
            ride.ActualDistanceKm,
            ride.EstimatedDurationMin,
            ride.ActualDurationMin,
            ride.RequestedAt,
            ride.CompletedAt,
            ride.PickupAddress,
            ride.DropoffAddress,
            driver?.Name,
            ride.RatingByRider);
    }
}
