namespace PondyConnect.Api.Controllers;

using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using PondyConnect.Api.Filters;
using PondyConnect.Api.Services;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.RideHailing;
using PondyConnect.Application.Services;
using PondyConnect.Domain.Enums;

[ApiController]
[Route("api")]
public sealed class RideHailingController : ControllerBase
{
    private readonly IMediator _mediator;
    private readonly RideDispatchService _dispatchService;
    private readonly DispatchEngine _dispatchEngine;
    private readonly IApplicationDbContext _dbContext;
    private readonly ICurrentUserService _currentUser;
    private readonly IIdempotencyService _idempotency;
    private readonly TripLifecycleService _tripLifecycle;

    public RideHailingController(
        IMediator mediator,
        RideDispatchService dispatchService,
        DispatchEngine dispatchEngine,
        IApplicationDbContext dbContext,
        ICurrentUserService currentUser,
        IIdempotencyService idempotency,
        TripLifecycleService tripLifecycle)
    {
        _mediator = mediator;
        _dispatchService = dispatchService;
        _dispatchEngine = dispatchEngine;
        _dbContext = dbContext;
        _currentUser = currentUser;
        _idempotency = idempotency;
        _tripLifecycle = tripLifecycle;
    }

    [HttpPost("rides")]
    [HttpPost("rides/request")]
    [Authorize]
    [RequireWaiver]
    [EnableRateLimiting("OrderPolicy")]
    [ProducesResponseType(typeof(RideRequestResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status422UnprocessableEntity)]
    public async Task<ActionResult<RideRequestResponse>> RequestRide([FromBody] RequestRideRequest request, CancellationToken ct)
    {
        // Validate coordinate ranges
        if (request.PickupLatitude < -90 || request.PickupLatitude > 90 ||
            request.DropoffLatitude < -90 || request.DropoffLatitude > 90 ||
            request.PickupLongitude < -180 || request.PickupLongitude > 180 ||
            request.DropoffLongitude < -180 || request.DropoffLongitude > 180)
        {
            return BadRequest(new { Message = "Invalid coordinates. Latitude must be between -90 and 90, longitude between -180 and 180." });
        }

        var idempotencyKey = Request.Headers["Idempotency-Key"].FirstOrDefault();
        var cacheKey = $"ride:{Request.Path}:{idempotencyKey}";

        if (!string.IsNullOrWhiteSpace(idempotencyKey))
        {
            var cached = await _idempotency.GetAsync<RideRequestResponse>(cacheKey, ct);
            if (cached is not null)
                return Ok(cached);
        }

        var cmd = new RequestRideCommand(
            request.PickupLatitude,
            request.PickupLongitude,
            request.PickupAddress,
            request.DropoffLatitude,
            request.DropoffLongitude,
            request.DropoffAddress,
            request.DistanceKm,
            request.VehicleType,
            request.PaymentMethod,
            request.IsSosRequest,
            request.RazorpayOrderId,
            request.RazorpayPaymentId,
            request.RazorpaySignature);
        var result = await _mediator.Send(cmd, ct);

        if (!string.IsNullOrWhiteSpace(idempotencyKey))
        {
            await _idempotency.SetAsync(cacheKey, result, TimeSpan.FromHours(24), ct);
        }

        await _dispatchService.BroadcastRideRequestAsync(result.RideId, ct);
        return Ok(result);
    }

    [HttpPost("rides/{id:guid}/accept")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(RideRequestResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<RideRequestResponse>> AcceptRide(Guid id, CancellationToken ct)
    {
        // Resolve the authenticated driver's ID
        var userId = _currentUser.UserId;
        if (userId == null)
            return Unauthorized();

        var driverId = await _dbContext.Drivers.AsNoTracking()
            .Where(d => d.UserId == userId && d.IsApproved)
            .Select(d => d.Id)
            .FirstOrDefaultAsync(ct);

        if (driverId == Guid.Empty)
            return NotFound(new { Message = "Driver profile not found or not approved." });

        // Use the dispatch engine's distributed lock to prevent race conditions
        var accepted = await _dispatchEngine.TryAcceptOfferAsync(id, driverId, ct);
        if (!accepted)
            return Conflict(new { Message = "Ride already accepted by another driver or no longer available." });

        // Fetch the updated ride to return the response
        var ride = await _dbContext.RideRequests.AsNoTracking()
            .FirstOrDefaultAsync(r => r.Id == id, ct);

        return Ok(new RideRequestResponse(
            ride!.Id, ride.DistanceKm, ride.EstimatedDurationMin, ride.Fare,
            ride.Fare, ride.PlatformBookingFee, ride.TotalAmount, ride.Status.ToString(),
            ride.VehicleType.ToString(), ride.PaymentMethod.ToString()));
    }

    [HttpPost("rides/{id:guid}/start")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> StartRide(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new StartRideCommand(id), ct);
        return NoContent();
    }

    [HttpPost("rides/{id:guid}/complete")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CompleteRide(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new CompleteRideCommand(id), ct);
        return NoContent();
    }

    [HttpPost("rides/{id:guid}/cancel")]
    [Authorize]
    public async Task<IActionResult> CancelRide(Guid id, [FromBody] CancelRideRequest? request, CancellationToken ct)
    {
        await _mediator.Send(new CancelRideCommand(id, request?.Reason), ct);
        return NoContent();
    }

    [HttpGet("rides/{id:guid}")]
    [Authorize]
    [ProducesResponseType(typeof(RideDetailResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<RideDetailResponse>> GetRide(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetRideQuery(id), ct);
        if (result is null) return NotFound(new { Message = "Ride not found." });
        return Ok(result);
    }

    [HttpGet("rides")]
    [HttpGet("rides/my-rides")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<RideSummaryResponse>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<RideSummaryResponse>>> ListRides([FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
    {
        var result = await _mediator.Send(new ListUserRidesQuery(page, pageSize), ct);
        if (result is null) return Ok(Array.Empty<RideSummaryResponse>());
        return Ok(result);
    }

    [HttpGet("rides/nearby-drivers")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<NearbyDriverResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<IReadOnlyList<NearbyDriverResponse>>> NearbyDrivers([FromQuery] double lat, [FromQuery] double lng, [FromQuery] double radius = 3.0, CancellationToken ct = default)
    {
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180)
            return BadRequest(new { Message = "Invalid coordinates." });
        if (radius <= 0 || radius > 20)
            return BadRequest(new { Message = "Radius must be between 0 and 20 km." });

        var result = await _mediator.Send(new GetNearbyDriversQuery(lat, lng, radius), ct);
        return Ok(result);
    }

    // === Phase 2+ new endpoints: ride lifecycle, OTP, ratings, cancellation, safety ===

    [HttpPost("rides/{id:guid}/arrive")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> ArriveAtPickup(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ArriveAtPickupCommand(id), ct);
        return NoContent();
    }

    [HttpPost("rides/{id:guid}/verify-otp")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> VerifyOtpAndStart(Guid id, [FromBody] VerifyOtpRequest request, CancellationToken ct)
    {
        await _mediator.Send(new VerifyOtpAndStartCommand(id, request.Otp), ct);
        return NoContent();
    }

    /// <summary>
    /// Testing helper: returns the ride-start OTP for the specified ride.
    /// Only available when the OTP service is in test/mock mode.
    /// The rider or the assigned driver can peek.
    /// </summary>
    [HttpGet("rides/{id:guid}/otp/peek")]
    [Authorize]
    [ProducesResponseType(typeof(PeekRideOtpResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<PeekRideOtpResponse>> PeekRideOtp(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new PeekRideOtpQuery(id), ct);
        if (result.Otp is null)
            return NotFound(new { Message = "OTP not available for peek. Either no code was issued, the ride hasn't been accepted yet, or peek is disabled in production." });
        return Ok(result);
    }

    [HttpPost("rides/{id:guid}/complete-with-metrics")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> CompleteWithMetrics(Guid id, [FromBody] CompleteWithMetricsRequest request, CancellationToken ct)
    {
        await _mediator.Send(new CompleteRideWithMetricsCommand(id, request.ActualDistanceKm, request.ActualDurationMin), ct);
        return NoContent();
    }

    [HttpPost("rides/{id:guid}/cancel-by-rider")]
    [Authorize]
    public async Task<ActionResult<CancelRideResponse>> CancelByRider(Guid id, [FromBody] CancelRideRequest? request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CancelRideByRiderCommand(id, request?.Reason, request?.WaiveFee ?? false), ct);
        return Ok(result);
    }

    [HttpPost("rides/{id:guid}/cancel-by-driver")]
    [Authorize(Roles = "Driver")]
    public async Task<IActionResult> CancelByDriver(Guid id, [FromBody] CancelRideRequest? request, CancellationToken ct)
    {
        await _mediator.Send(new CancelRideByDriverCommand(id, request?.Reason), ct);
        return NoContent();
    }

    /// <summary>
    /// COD exact-change reconciliation. When a driver collects more cash than
    /// the order total, the change is debited from the driver's ledger and
    /// credited to the consumer's PY Wallet instantly.
    /// </summary>
    [HttpPost("rides/{id:guid}/cod-reconcile")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(CodReconcileResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<ActionResult<CodReconcileResponse>> CodReconcile(Guid id, [FromBody] CodReconcileRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new CodReconcileCommand(id, request.CollectedAmount, request.OrderTotal), ct);
        return Ok(result);
    }

    [HttpPost("rides/{id:guid}/rate")]
    [Authorize]
    public async Task<IActionResult> RateRide(Guid id, [FromBody] RateRideRequest request, CancellationToken ct)
    {
        await _mediator.Send(new RateRideCommand(id, request.Rating, request.Feedback), ct);
        return NoContent();
    }

    [HttpPost("rides/{id:guid}/share")]
    [Authorize]
    public async Task<ActionResult<TripShareResponse>> EnableTripSharing(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new EnableTripSharingCommand(id), ct);
        return Ok(result);
    }

    [HttpGet("trip/{token:guid}")]
    [ProducesResponseType(typeof(TripShareDetailResponse), StatusCodes.Status200OK)]
    public async Task<ActionResult<TripShareDetailResponse>> GetTripShare(Guid token, CancellationToken ct)
    {
        try
        {
            var result = await _mediator.Send(new GetTripShareQuery(token), ct);
            return Ok(result);
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "Trip not found or sharing disabled." });
        }
    }

    [HttpPost("rides/{id:guid}/sos")]
    [Authorize]
    public async Task<ActionResult<SosAlertResponse>> TriggerSos(Guid id, [FromBody] TriggerSosRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new TriggerSosCommand(id, request.Latitude, request.Longitude), ct);
        return Ok(result);
    }

    [HttpPost("rides/{id:guid}/sos/resolve")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ResolveSos(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ResolveSosCommand(id), ct);
        return NoContent();
    }

    [HttpPost("emergency-contacts")]
    [Authorize]
    public async Task<ActionResult<EmergencyContactResponse>> AddEmergencyContact([FromBody] AddEmergencyContactRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new AddEmergencyContactCommand(request.Name, request.Phone, request.Relationship), ct);
        return Ok(result);
    }

    [HttpGet("emergency-contacts")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<EmergencyContactResponse>>> ListEmergencyContacts(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListEmergencyContactsQuery(), ct);
        return Ok(result);
    }

    [HttpDelete("emergency-contacts/{id:guid}")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteEmergencyContact(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteEmergencyContactCommand(id), ct);
        return NoContent();
    }

    [HttpGet("rides/{id:guid}/receipt")]
    [Authorize]
    public async Task<ActionResult<RideReceiptResponse>> GetReceipt(Guid id, CancellationToken ct)
    {
        try
        {
            var result = await _mediator.Send(new GetRideReceiptQuery(id), ct);
            return Ok(result);
        }
        catch (InvalidOperationException)
        {
            return NotFound(new { Message = "Ride not found." });
        }
    }

    // === Saved Locations ===

    [HttpGet("saved-locations")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<SavedLocationResponse>>> ListSavedLocations(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListSavedLocationsQuery(), ct);
        return Ok(result);
    }

    [HttpPost("saved-locations")]
    [Authorize]
    public async Task<ActionResult<SavedLocationResponse>> AddSavedLocation([FromBody] AddSavedLocationRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new AddSavedLocationCommand(request.Label, request.Address, request.Latitude, request.Longitude), ct);
        return Ok(result);
    }

    [HttpPut("saved-locations/{id:guid}")]
    [Authorize]
    public async Task<IActionResult> UpdateSavedLocation(Guid id, [FromBody] AddSavedLocationRequest request, CancellationToken ct)
    {
        await _mediator.Send(new UpdateSavedLocationCommand(id, request.Label, request.Address, request.Latitude, request.Longitude), ct);
        return NoContent();
    }

    [HttpDelete("saved-locations/{id:guid}")]
    [Authorize]
    public async Task<IActionResult> DeleteSavedLocation(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new DeleteSavedLocationCommand(id), ct);
        return NoContent();
    }

    // === Scheduled Rides ===

    [HttpGet("scheduled-rides")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<ScheduledRideResponse>>> ListScheduledRides(CancellationToken ct)
    {
        var result = await _mediator.Send(new ListScheduledRidesQuery(), ct);
        return Ok(result);
    }

    [HttpPost("scheduled-rides")]
    [Authorize]
    public async Task<ActionResult<ScheduledRideResponse>> ScheduleRide([FromBody] ScheduleRideRequest request, CancellationToken ct)
    {
        var result = await _mediator.Send(new ScheduleRideCommand(
            request.PickupLatitude, request.PickupLongitude, request.PickupAddress,
            request.DropoffLatitude, request.DropoffLongitude, request.DropoffAddress,
            request.DistanceKm, request.VehicleType, request.PaymentMethod,
            request.ScheduledAt, request.EstimatedFare), ct);
        return Ok(result);
    }

    [HttpPost("scheduled-rides/{id:guid}/cancel")]
    [Authorize]
    public async Task<IActionResult> CancelScheduledRide(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new CancelScheduledRideCommand(id), ct);
        return NoContent();
    }

    // === Driver Earnings ===

    [HttpGet("driver/earnings")]
    [Authorize(Roles = "Driver")]
    public async Task<ActionResult<DriverEarningsResponse>> GetDriverEarnings([FromQuery] DateTimeOffset? from, [FromQuery] DateTimeOffset? to, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetDriverEarningsQuery(from, to), ct);
        return Ok(result);
    }

    // === Ride Events Timeline ===

    [HttpGet("rides/{id:guid}/events")]
    [Authorize]
    public async Task<ActionResult<IReadOnlyList<RideEventResponse>>> GetRideEvents(Guid id, CancellationToken ct)
    {
        var result = await _mediator.Send(new GetRideEventsQuery(id), ct);
        return Ok(result);
    }

    // === Driver Reassignment ===

    [HttpPost("rides/{id:guid}/reassign")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ReassignRide(Guid id, CancellationToken ct)
    {
        await _mediator.Send(new ReassignRideCommand(id), ct);
        return NoContent();
    }

    // === Edge-Case: Mid-Trip Breakdown Split & Re-Dispatch ===

    /// <summary>
    /// Handles a mid-trip vehicle breakdown. Splits the ride into two legs:
    /// Leg 1 (pickup → breakdown) is completed with a prorated fare, and
    /// Leg 2 (breakdown → original dropoff) is created as a new ride with
    /// priority dispatch to nearby drivers.
    /// </summary>
    [HttpPost("rides/{id:guid}/breakdown")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(BreakdownSplitResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<BreakdownSplitResponse>> Breakdown(
        Guid id,
        [FromBody] BreakdownRequest request,
        CancellationToken ct)
    {
        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return Unauthorized(new { Message = "Driver profile not found." });

        try
        {
            var result = await _tripLifecycle.HandleBreakdownAsync(id, driverId.Value, request.Latitude, request.Longitude, ct);

            // Dispatch the split ride (Leg 2) to nearby drivers with high priority
            _ = _dispatchService.BroadcastRideRequestAsync(result.SplitRideId, ct);

            return Ok(new BreakdownSplitResponse(
                result.OriginalRideId,
                result.SplitRideId,
                result.Leg1Fare,
                result.Leg2Fare,
                result.TraveledDistanceKm,
                result.RemainingDistanceKm));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
    }

    // === Edge-Case: Rider No-Show Cancellation ===

    /// <summary>
    /// Declares a rider no-show at pickup. The captain must have arrived
    /// and waited at least 5 minutes. The rider is charged a ₹50
    /// cancellation fee credited to the captain's wallet.
    /// </summary>
    [HttpPost("rides/{id:guid}/rider-no-show")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(RiderNoShowResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<RiderNoShowResponse>> RiderNoShow(Guid id, CancellationToken ct)
    {
        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return Unauthorized(new { Message = "Driver profile not found." });

        try
        {
            var fee = await _tripLifecycle.HandleRiderNoShowAsync(id, driverId.Value, ct);
            return Ok(new RiderNoShowResponse(id, fee, "Rider no-show declared. ₹50 credited to your wallet."));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
    }

    // === Edge-Case: Route Deviation Fare Lock ===

    /// <summary>
    /// Locks the fare due to route deviation (>1.5km from suggested
    /// polyline). Prevents inflated metered charges during safety review.
    /// Alerts the admin SOS hub.
    /// </summary>
    [HttpPost("rides/{id:guid}/lock-fare")]
    [Authorize]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> LockFare(Guid id, CancellationToken ct)
    {
        try
        {
            await _tripLifecycle.LockFareForDeviationAsync(id, ct);
            return Ok(new { Message = "Fare locked due to route deviation. Admin alerted for safety review." });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
    }

    // === Edge-Case: Toll & Parking Pass-Through ===

    /// <summary>
    /// Adds a toll/parking pass-through surcharge to the ride. The captain
    /// enters the receipt amount before ending the trip. Zero platform
    /// deduction — 100% goes to the driver.
    /// </summary>
    [HttpPost("rides/{id:guid}/toll-parking")]
    [Authorize(Roles = "Driver")]
    [ProducesResponseType(typeof(TollParkingResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<TollParkingResponse>> AddTollAndParking(
        Guid id,
        [FromBody] TollParkingRequest request,
        CancellationToken ct)
    {
        var driverId = await ResolveDriverIdAsync(ct);
        if (driverId is null)
            return Unauthorized(new { Message = "Driver profile not found." });

        try
        {
            await _tripLifecycle.AddTollAndParkingAsync(id, driverId.Value, request.Amount, request.ReceiptUrl, ct);
            return Ok(new TollParkingResponse(id, request.Amount, "Toll/parking surcharge added."));
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { Message = ex.Message });
        }
        catch (UnauthorizedAccessException)
        {
            return Forbid();
        }
    }

    private async Task<Guid?> ResolveDriverIdAsync(CancellationToken ct)
    {
        var userId = _currentUser.UserId;
        if (userId is null)
            return null;
        var driver = await _dbContext.Drivers.AsNoTracking()
            .FirstOrDefaultAsync(d => d.UserId == userId.Value, ct);
        return driver?.Id;
    }
}

public sealed record VerifyOtpRequest(string Otp);
public sealed record CompleteWithMetricsRequest(double ActualDistanceKm, int ActualDurationMin);
public sealed record RateRideRequest(int Rating, string? Feedback = null);
public sealed record TriggerSosRequest(double Latitude, double Longitude);
public sealed record AddEmergencyContactRequest(string Name, string Phone, string? Relationship = null);
public sealed record AddSavedLocationRequest(string Label, string Address, double Latitude, double Longitude);
public sealed record ScheduleRideRequest(
    double PickupLatitude, double PickupLongitude, string PickupAddress,
    double DropoffLatitude, double DropoffLongitude, string DropoffAddress,
    double DistanceKm, int VehicleType, int PaymentMethod,
    DateTimeOffset ScheduledAt, decimal EstimatedFare);

public sealed record RequestRideRequest(
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
    string? RazorpaySignature = null);

public sealed record CancelRideRequest(string? Reason, bool WaiveFee = false);

public sealed record CodReconcileRequest(decimal CollectedAmount, decimal OrderTotal);

public sealed record BreakdownRequest(double Latitude, double Longitude);
public sealed record BreakdownSplitResponse(Guid OriginalRideId, Guid SplitRideId, decimal Leg1Fare, decimal Leg2Fare, double TraveledDistanceKm, double RemainingDistanceKm);
public sealed record RiderNoShowResponse(Guid RideId, decimal CancellationFee, string Message);
public sealed record TollParkingRequest(decimal Amount, string? ReceiptUrl = null);
public sealed record TollParkingResponse(Guid RideId, decimal Amount, string Message);
