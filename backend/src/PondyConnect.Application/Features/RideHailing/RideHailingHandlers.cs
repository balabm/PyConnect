namespace PondyConnect.Application.Features.RideHailing;

using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Notifications;
using PondyConnect.Application.Features.Referral;
using PondyConnect.Application.Services;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;
using PondyConnect.Application.Features.GeoFence;
using PondyConnect.Application.Features.Fraud;
using PondyConnect.Application.Features.Wallet;

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
    bool IsSosRequest = false,
    string? RazorpayOrderId = null,
    string? RazorpayPaymentId = null,
    string? RazorpaySignature = null) : IRequest<RideRequestResponse>;

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
    private readonly IFraudDetectionService? _fraudDetection;
    private readonly IPaymentGateway _gateway;
    private readonly IPaymentRefundService _refundService;
    private readonly ILogger<RequestRideHandler> _logger;

    public RequestRideHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        ServiceAreaValidator serviceArea,
        SurgeCalculator surgeCalculator,
        IPaymentGateway gateway,
        IPaymentRefundService refundService,
        ILogger<RequestRideHandler> logger,
        IFraudDetectionService? fraudDetection = null,
        IRoutingService? routingService = null)
    {
        _context = context;
        _currentUser = currentUser;
        _serviceArea = serviceArea;
        _surgeCalculator = surgeCalculator;
        _gateway = gateway;
        _refundService = refundService;
        _logger = logger;
        _fraudDetection = fraudDetection;
        _routingService = routingService;
    }

    public async Task<RideRequestResponse> Handle(RequestRideCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        // COD enforcement: consumers flagged with CodRestricted cannot pay cash.
        if (request.PaymentMethod == PaymentMethod.Cash
            && _fraudDetection is not null
            && await _fraudDetection.IsCodRestrictedAsync(userId.ToString()))
        {
            throw new CodRestrictedException();
        }

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

        // Wrap the "payment verified -> persist ride" step in an explicit
        // transaction. If the database fails to commit after Razorpay has
        // captured the money, we refund the consumer automatically.
        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);

        string? paymentId = null;
        var verifiedAmount = ride.TotalAmount;

        try
        {
            // Online payments must have a valid Razorpay client-side signature.
            if (request.PaymentMethod != PaymentMethod.Cash)
            {
                if (string.IsNullOrWhiteSpace(request.RazorpayOrderId)
                    || string.IsNullOrWhiteSpace(request.RazorpayPaymentId)
                    || string.IsNullOrWhiteSpace(request.RazorpaySignature))
                {
                    throw new InvalidOperationException("Razorpay payment details are required for online payment.");
                }

                var signatureValid = await _gateway.VerifyPaymentSignatureAsync(
                    request.RazorpayOrderId,
                    request.RazorpayPaymentId,
                    request.RazorpaySignature,
                    cancellationToken);

                if (!signatureValid)
                    throw new InvalidOperationException("Payment signature verification failed.");

                paymentId = request.RazorpayPaymentId;
            }

            _context.RideRequests.Add(ride);
            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            var driverEarnings = isSos ? sosDriverPayout : ride.Fare;

            return new RideRequestResponse(
                ride.Id, ride.DistanceKm, ride.EstimatedDurationMin, ride.Fare,
                driverEarnings, ride.PlatformBookingFee, ride.TotalAmount, ride.Status.ToString(),
                ride.VehicleType.ToString(), ride.PaymentMethod.ToString());
        }
        catch (Exception ex)
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);

            if (!string.IsNullOrEmpty(paymentId))
            {
                _logger.LogCritical(
                    ex,
                    "CRITICAL_AUTO_REFUND: Ride creation failed after payment {PaymentId}. Initiating refund.",
                    paymentId);
                _ = await _refundService.RefundAsync(
                    paymentId,
                    verifiedAmount,
                    "Ride creation failed after payment",
                    cancellationToken);
            }
            else
            {
                _logger.LogCritical(
                    ex,
                    "CRITICAL_AUTO_REFUND: Ride creation failed before payment could be verified.");
            }

            throw;
        }
    }
}

public sealed record AcceptRideCommand(Guid RideId) : IRequest<RideRequestResponse>;

public sealed class AcceptRideHandler : IRequestHandler<AcceptRideCommand, RideRequestResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly INotificationService? _notifications;

    public AcceptRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
    }

    public AcceptRideHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
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

        // Fire-and-forget push to the consumer so they know a driver is on the
        // way. The push must not fail the ride-acceptance transaction.
        if (_notifications is not null)
        {
            _ = SendDriverAcceptedPushAsync(ride, driver, cancellationToken);
        }

        return new RideRequestResponse(
            ride.Id, ride.DistanceKm, ride.EstimatedDurationMin, ride.Fare,
            ride.Fare, ride.PlatformBookingFee, ride.TotalAmount, ride.Status.ToString(),
            ride.VehicleType.ToString(), ride.PaymentMethod.ToString());
    }

    /// <summary>
    /// Best-effort FCM push to the rider when a driver accepts their ride.
    /// All exceptions are swallowed so a Firebase failure never surfaces.
    /// </summary>
    private async Task SendDriverAcceptedPushAsync(RideRequest ride, Driver driver, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendHighPriorityPushAsync(
                ride.UserId,
                "Driver on the way!",
                $"{driver.Name} is heading to your pickup location.",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}" },
                    { "type", "ride_accepted" },
                    { "ride_id", ride.Id.ToString() },
                    { "driver_id", driver.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the ride-acceptance flow.
        }
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
    private readonly INotificationService? _notifications;
    private readonly WalletService? _walletService;
    private readonly ReferralService? _referralService;

    public CompleteRideHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
        _walletService = null;
        _referralService = null;
    }

    public CompleteRideHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
        _walletService = null;
        _referralService = null;
    }

    public CompleteRideHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications, WalletService walletService)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
        _walletService = walletService;
        _referralService = null;
    }

    public CompleteRideHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications, WalletService walletService, ReferralService referralService)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
        _walletService = walletService;
        _referralService = referralService;
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

        // COD commission: when the rider pays cash, the driver collects the
        // full fare and owes the platform a 10% commission. Debit the
        // driver's cash-collection wallet and suspend if the hard limit is
        // reached.
        if (_walletService is not null
            && ride.PaymentMethod == PaymentMethod.Cash
            && ride.DriverId.HasValue
            && ride.Fare > 0m)
        {
            var commission = Math.Round(ride.Fare * 0.1m, 2, MidpointRounding.AwayFromZero);
            if (commission > 0m)
            {
                await _walletService.RecordCommissionAsync(
                    ride.DriverId.Value,
                    commission,
                    ride.Id.ToString(),
                    $"COD commission for ride {ride.Id}",
                    cancellationToken);

                await _walletService.CheckAndSuspendIfNeededAsync(ride.DriverId.Value, cancellationToken);
            }
        }

        // Fire-and-forget push to the consumer — ride is complete, prompt for rating.
        if (_notifications is not null)
        {
            _ = SendRideCompletedPushAsync(ride, cancellationToken);
        }

        // Process deferred referral payout when the ride completes.
        if (_referralService is not null)
        {
            _ = _referralService.ProcessOrderCompletionAsync(ride.UserId, ride.Id, cancellationToken);
        }

        return Unit.Value;
    }

    /// <summary>
    /// Best-effort FCM push to the rider when the ride is completed.
    /// All exceptions are swallowed so a Firebase failure never surfaces.
    /// </summary>
    private async Task SendRideCompletedPushAsync(RideRequest ride, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendTargetedPushAsync(
                ride.UserId,
                "Ride completed!",
                $"Your ride has been completed. Fare: \u20B9{ride.TotalAmount.ToString("0", System.Globalization.CultureInfo.InvariantCulture)}. Rate your experience!",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}/receipt" },
                    { "type", "ride_completed" },
                    { "ride_id", ride.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the ride-completion flow.
        }
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

/// <summary>
/// Completes a high-value ride after verifying the completion OTP collected
/// from the customer at drop-off. Delegates the wallet/notification logic to
/// the same post-completion pipeline as CompleteRideHandler.
/// </summary>
public sealed record CompleteRideWithOtpCommand(Guid RideId, string? Otp) : IRequest<Unit>;

public sealed class CompleteRideWithOtpHandler : IRequestHandler<CompleteRideWithOtpCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly INotificationService? _notifications;
    private readonly WalletService? _walletService;
    private readonly ReferralService? _referralService;

    public CompleteRideWithOtpHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
        _walletService = null;
        _referralService = null;
    }

    public CompleteRideWithOtpHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        INotificationService notifications,
        WalletService walletService,
        ReferralService referralService)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
        _walletService = walletService;
        _referralService = referralService;
    }

    public async Task<Unit> Handle(CompleteRideWithOtpCommand request, CancellationToken cancellationToken)
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

        // Verify OTP and complete
        ride.CompleteWithOtp(request.Otp);

        // Clear the driver's active ride state
        if (ride.DriverId.HasValue)
        {
            var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.Id == ride.DriverId.Value, cancellationToken);
            driver?.EndRide();
        }

        _context.RideEvents.Add(RideEvent.Create(ride.Id, RideEventType.Completed, ride.DriverId));
        await _context.SaveChangesAsync(cancellationToken);

        // COD commission — same as CompleteRideHandler
        if (_walletService is not null
            && ride.PaymentMethod == PaymentMethod.Cash
            && ride.DriverId.HasValue
            && ride.Fare > 0m)
        {
            var commission = Math.Round(ride.Fare * 0.1m, 2, MidpointRounding.AwayFromZero);
            if (commission > 0m)
            {
                await _walletService.RecordCommissionAsync(
                    ride.DriverId.Value,
                    commission,
                    ride.Id.ToString(),
                    $"COD commission for ride {ride.Id}",
                    cancellationToken);

                await _walletService.CheckAndSuspendIfNeededAsync(ride.DriverId.Value, cancellationToken);
            }
        }

        // Push notification to rider
        if (_notifications is not null)
        {
            _ = SendRideCompletedPushAsync(ride, cancellationToken);
        }

        // Referral payout
        if (_referralService is not null)
        {
            _ = _referralService.ProcessOrderCompletionAsync(ride.UserId, ride.Id, cancellationToken);
        }

        return Unit.Value;
    }

    private async Task SendRideCompletedPushAsync(Domain.Entities.RideRequest ride, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendTargetedPushAsync(
                ride.UserId,
                "Ride completed!",
                $"Your ride has been completed. Fare: \u20B9{ride.TotalAmount.ToString("0", System.Globalization.CultureInfo.InvariantCulture)}. Rate your experience!",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}/receipt" },
                    { "type", "ride_completed" },
                    { "ride_id", ride.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort
        }
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
    DateTimeOffset? StartedAt,
    DateTimeOffset? CompletedAt,
    Guid? DriverId,
    string? OtpCode);

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
            ride.Status.ToString(), ride.RequestedAt, ride.AcceptedAt, ride.StartedAt, ride.CompletedAt, ride.DriverId,
            userId == ride.UserId ? ride.OtpCode : null);
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

public sealed record NearbyDriverResponse(Guid Id, string Name, string VehicleType, double DistanceKm, double Rating, int TotalRides, double Latitude, double Longitude);

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
            .Select(x => new NearbyDriverResponse(x.Driver.Id, x.Driver.Name, x.Driver.VehicleType.ToString(), x.Distance, x.Driver.Rating, x.Driver.TotalRides, x.Driver.CurrentLocation.Latitude, x.Driver.CurrentLocation.Longitude))
            .ToList();
    }
}

public sealed record RegisterDriverCommand(string Name, string Phone, VehicleType VehicleType, string? VehiclePlate = null, string? LicenseNumber = null) : IRequest<RegisterDriverResponse>;

public sealed record DriverResponse(Guid Id, string Name, string Phone, string VehicleType, string? VehiclePlate, bool IsApproved, bool IsOnline, double Rating, int TotalRides);

public sealed record RegisterDriverResponse(Guid Id, string Name, string Phone, string VehicleType, string? VehiclePlate, bool IsApproved, bool IsOnline, double Rating, int TotalRides, string? AccessToken = null);

public sealed class RegisterDriverHandler : IRequestHandler<RegisterDriverCommand, RegisterDriverResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IJwtTokenFactory? _jwtTokenFactory;

    public RegisterDriverHandler(IApplicationDbContext context, ICurrentUserService currentUser, IJwtTokenFactory? jwtTokenFactory = null)
    {
        _context = context;
        _currentUser = currentUser;
        _jwtTokenFactory = jwtTokenFactory;
    }

    public async Task<RegisterDriverResponse> Handle(RegisterDriverCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        // Use the authenticated user's phone if the request phone doesn't match.
        // This prevents a user from registering as a driver with someone else's phone.
        var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == userId, cancellationToken);
        if (user is not null && user.Role != UserRole.Driver && user.Role != UserRole.Admin)
            user.ChangeRole(UserRole.Driver);

        // Use the authenticated user's phone for the driver record to ensure
        // consistency between the user account and the driver profile.
        var driverPhone = user?.Phone ?? request.Phone;

        var driver = Driver.Create(userId, request.Name, driverPhone, request.VehicleType, request.VehiclePlate);

        // Store the license number if provided during registration.
        if (!string.IsNullOrWhiteSpace(request.LicenseNumber))
            driver.SetKycLicenseNumber(request.LicenseNumber);

        _context.Drivers.Add(driver);
        await _context.SaveChangesAsync(cancellationToken);

        // Issue a fresh JWT with the Driver role so the client doesn't need
        // to re-authenticate to get a token with the correct role claim.
        string? newToken = null;
        if (_jwtTokenFactory is not null && user is not null)
            newToken = _jwtTokenFactory.CreateAccessToken(user.Id, user.Phone, user.Role.ToString());

        return new RegisterDriverResponse(driver.Id, driver.Name, driver.Phone, driver.VehicleType.ToString(), driver.VehiclePlate, driver.IsApproved, driver.IsOnline, driver.Rating, driver.TotalRides, newToken);
    }
}

public sealed record ToggleDriverOnlineCommand(bool GoOnline) : IRequest<Unit>;
public sealed record UpdateDriverLocationCommand(double Latitude, double Longitude) : IRequest<Unit>;

public sealed class ToggleDriverOnlineHandler : IRequestHandler<ToggleDriverOnlineCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly WalletService? _walletService;

    public ToggleDriverOnlineHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _walletService = null;
    }

    public ToggleDriverOnlineHandler(IApplicationDbContext context, ICurrentUserService currentUser, WalletService walletService)
    {
        _context = context;
        _currentUser = currentUser;
        _walletService = walletService;
    }

    public async Task<Unit> Handle(ToggleDriverOnlineCommand request, CancellationToken cancellationToken)
    {
        var userId = _currentUser.UserId ?? throw new UnauthorizedAccessException("User not authenticated.");

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.UserId == userId, cancellationToken)
            ?? throw new InvalidOperationException("Driver profile not found.");

        if (request.GoOnline)
        {
            // Block going online when the cash-collection wallet is suspended
            // (driver owes outstanding COD commission dues past the hard limit).
            if (_walletService is not null)
            {
                var wallet = await _walletService.GetOrCreateWalletAsync(driver.Id, cancellationToken);
                if (wallet.Suspended)
                    throw new WalletSuspendedException();
            }

            driver.GoOnline();
        }
        else
        {
            driver.GoOffline();
        }

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
    private readonly INotificationService? _notifications;

    public ArriveAtPickupHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
    }

    public ArriveAtPickupHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
    }

    public async Task<Unit> Handle(ArriveAtPickupCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        await ValidateDriverOwnershipAsync(ride, cancellationToken);
        ride.ArriveAtPickup();
        await _context.SaveChangesAsync(cancellationToken);

        if (_notifications is not null)
        {
            _ = SendDriverArrivedPushAsync(ride, cancellationToken);
        }

        return Unit.Value;
    }

    private async Task SendDriverArrivedPushAsync(RideRequest ride, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendTargetedPushAsync(
                ride.UserId,
                "Driver has arrived!",
                $"Your driver has arrived at {ride.PickupAddress}.",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}" },
                    { "type", "driver_arrived" },
                    { "ride_id", ride.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the arrival flow.
        }
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
    private readonly INotificationService? _notifications;

    public VerifyOtpAndStartHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
    }

    public VerifyOtpAndStartHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
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

        if (_notifications is not null)
        {
            _ = SendRideStartedPushAsync(ride, cancellationToken);
        }

        return Unit.Value;
    }

    private async Task SendRideStartedPushAsync(RideRequest ride, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendTargetedPushAsync(
                ride.UserId,
                "Ride started!",
                $"Your ride to {ride.DropoffAddress} is now en route.",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}" },
                    { "type", "ride_started" },
                    { "ride_id", ride.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the start flow.
        }
    }
}

public sealed record CompleteRideWithMetricsCommand(Guid RideId, double ActualDistanceKm, int ActualDurationMin) : IRequest<Unit>;

public sealed class CompleteRideWithMetricsHandler : IRequestHandler<CompleteRideWithMetricsCommand, Unit>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly INotificationService? _notifications;

    public CompleteRideWithMetricsHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = null;
    }

    public CompleteRideWithMetricsHandler(IApplicationDbContext context, ICurrentUserService currentUser, INotificationService notifications)
    {
        _context = context;
        _currentUser = currentUser;
        _notifications = notifications;
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

        // Fire-and-forget push to the consumer — ride is complete, prompt for rating.
        if (_notifications is not null)
        {
            _ = SendRideCompletedPushAsync(ride, cancellationToken);
        }

        return Unit.Value;
    }

    private async Task SendRideCompletedPushAsync(RideRequest ride, CancellationToken cancellationToken)
    {
        try
        {
            await _notifications!.SendTargetedPushAsync(
                ride.UserId,
                "Ride completed!",
                $"Your ride has been completed. Fare: \u20B9{ride.TotalAmount.ToString("0", System.Globalization.CultureInfo.InvariantCulture)}. Rate your experience!",
                new Dictionary<string, string>
                {
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" },
                    { "route", $"/ride/{ride.Id}/receipt" },
                    { "type", "ride_completed" },
                    { "ride_id", ride.Id.ToString() },
                },
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the ride-completion flow.
        }
    }
}

public sealed record CancelRideByRiderCommand(Guid RideId, string? Reason = null, bool WaiveFee = false) : IRequest<CancelRideResponse>;

public sealed record CancelRideResponse(decimal CancellationFee, string Status, bool FeeWaived = false);

public sealed class CancelRideByRiderHandler : IRequestHandler<CancelRideByRiderCommand, CancelRideResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly IFraudDetectionService? _fraudDetection;
    private readonly IDriverLocationCache? _driverLocationCache;

    /// <summary>
    /// Stale-GPS threshold for fee waiver. If the driver's last GPS ping is
    /// older than this, the cancellation fee is automatically waived.
    /// </summary>
    private static readonly TimeSpan StaleGpsThreshold = TimeSpan.FromMinutes(3);

    public CancelRideByRiderHandler(IApplicationDbContext context, ICurrentUserService currentUser)
    {
        _context = context;
        _currentUser = currentUser;
        _fraudDetection = null;
        _driverLocationCache = null;
    }

    public CancelRideByRiderHandler(IApplicationDbContext context, ICurrentUserService currentUser, IFraudDetectionService fraudDetection)
    {
        _context = context;
        _currentUser = currentUser;
        _fraudDetection = fraudDetection;
        _driverLocationCache = null;
    }

    public CancelRideByRiderHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        IFraudDetectionService fraudDetection,
        IDriverLocationCache driverLocationCache)
    {
        _context = context;
        _currentUser = currentUser;
        _fraudDetection = fraudDetection;
        _driverLocationCache = driverLocationCache;
    }

    public async Task<CancelRideResponse> Handle(CancelRideByRiderCommand request, CancellationToken cancellationToken)
    {
        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        var userId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("User not authenticated.");
        if (ride.UserId != userId)
            throw new UnauthorizedAccessException("Only the rider who booked this ride can cancel it.");

        // Determine whether the cancellation fee should be waived:
        // 1. The client explicitly requests a waiver (driver GPS stale > 3 min)
        // 2. The server independently confirms the driver's GPS is stale
        var shouldWaive = request.WaiveFee;
        if (!shouldWaive && ride.DriverId.HasValue && _driverLocationCache is not null)
        {
            shouldWaive = _driverLocationCache.IsStale(ride.DriverId.Value, StaleGpsThreshold);
        }

        var fee = shouldWaive ? 0m : ride.CalculateCancellationFee();
        var wasDriverAssigned = ride.DriverId.HasValue;

        if (shouldWaive)
            ride.CancelByRiderWithWaiver(request.Reason);
        else
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

        // Track post-assignment cancellations for fraud detection. The service
        // checks if this is the 3rd+ cancellation in 24h and applies a COD
        // restriction flag if the threshold is met.
        if (wasDriverAssigned && _fraudDetection is not null)
        {
            await _fraudDetection.RecordCancellationAsync(userId.ToString(), ride.Id.ToString());
        }

        return new CancelRideResponse(fee, ride.Status.ToString(), FeeWaived: shouldWaive);
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

// ──────────────────────────────────────────────────────────────────────────
//  Edge 2.2: COD Exact-Change Reconciliation
//  When a driver collects more cash than the order total (e.g. customer
//  pays with a ₹500 note for a ₹130 order), the driver can reconcile the
//  change by debiting their own ledger and crediting the consumer's PY
//  Wallet instantly. Both parties walk away happy without needing exact
//  change.
// ──────────────────────────────────────────────────────────────────────────

public sealed record CodReconcileCommand(
    Guid RideId,
    decimal CollectedAmount,
    decimal OrderTotal) : IRequest<CodReconcileResponse>;

public sealed record CodReconcileResponse(
    decimal ChangeAmount,
    string Message);

public sealed class CodReconcileHandler : IRequestHandler<CodReconcileCommand, CodReconcileResponse>
{
    private readonly IApplicationDbContext _context;
    private readonly ICurrentUserService _currentUser;
    private readonly WalletService _walletService;

    public CodReconcileHandler(
        IApplicationDbContext context,
        ICurrentUserService currentUser,
        WalletService walletService)
    {
        _context = context;
        _currentUser = currentUser;
        _walletService = walletService;
    }

    public async Task<CodReconcileResponse> Handle(CodReconcileCommand request, CancellationToken cancellationToken)
    {
        var driverId = _currentUser.UserId
            ?? throw new UnauthorizedAccessException("Driver not authenticated.");

        var ride = await _context.RideRequests.FirstOrDefaultAsync(r => r.Id == request.RideId, cancellationToken)
            ?? throw new InvalidOperationException("Ride not found.");

        // Only the assigned driver can reconcile COD for this ride.
        if (ride.DriverId is null)
            throw new InvalidOperationException("This ride has no assigned driver.");

        var driver = await _context.Drivers.FirstOrDefaultAsync(d => d.UserId == driverId, cancellationToken)
            ?? throw new UnauthorizedAccessException("Driver profile not found.");

        if (ride.DriverId != driver.Id)
            throw new UnauthorizedAccessException("Only the assigned driver can reconcile COD for this ride.");

        // Only COD rides can be reconciled.
        if (ride.PaymentMethod != PaymentMethod.Cash)
            throw new InvalidOperationException("COD reconciliation is only available for cash-on-delivery rides.");

        // The collected amount must be >= the order total (driver can't
        // reconcile a shortfall — that's a different problem).
        if (request.CollectedAmount < request.OrderTotal)
            throw new InvalidOperationException(
                $"Collected amount (₹{request.CollectedAmount}) is less than the order total (₹{request.OrderTotal}). Cannot reconcile.");

        var changeAmount = request.CollectedAmount - request.OrderTotal;
        if (changeAmount <= 0)
            return new CodReconcileResponse(0, "No change to reconcile — exact amount collected.");

        // Debit the change from the driver's wallet ledger.
        await _walletService.RecordCommissionAsync(
            driver.Id,
            changeAmount,
            referenceId: $"cod-change-{ride.Id}",
            description: $"COD change reconciliation for ride {ride.Id} (collected ₹{request.CollectedAmount}, total ₹{request.OrderTotal})",
            cancellationToken);

        // Credit the change to the consumer's PY Wallet (real balance).
        var userWallet = await _context.UserWallets
            .FirstOrDefaultAsync(w => w.UserId == ride.UserId, cancellationToken);

        if (userWallet is null)
        {
            userWallet = UserWallet.Create(ride.UserId);
            _context.UserWallets.Add(userWallet);
        }

        userWallet.CreditReal(changeAmount);
        await _context.SaveChangesAsync(cancellationToken);

        return new CodReconcileResponse(
            changeAmount,
            $"₹{changeAmount} credited to the customer's PY Wallet. Your ledger has been debited.");
    }
}
