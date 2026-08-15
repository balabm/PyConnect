namespace PondyConnect.Domain.Entities;

using PondyConnect.Domain.Common;
using PondyConnect.Domain.Enums;
using PondyConnect.Domain.ValueObjects;

/// <summary>
/// A ride-hailing request with transparent upfront pricing.
/// DriverEarnings = Fare (100%). PlatformBookingFee = flat ₹15 charged to rider.
/// Supports dynamic surge (capped at 1.5x), OTP verification, two-way ratings,
/// and a rich lifecycle: Requested → Searching → DriverAssigned → ArrivedAtPickup
/// → EnRoute → Completed (or Cancelled at various stages).
/// </summary>
public sealed class RideRequest : BaseEntity
{
    public Guid UserId { get; private set; }

    public Guid? DriverId { get; private set; }

    public GeoLocation PickupLocation { get; private set; } = GeoLocation.Zero;

    public string PickupAddress { get; private set; } = string.Empty;

    public GeoLocation DropoffLocation { get; private set; } = GeoLocation.Zero;

    public string DropoffAddress { get; private set; } = string.Empty;

    public double DistanceKm { get; private set; }

    public int EstimatedDurationMin { get; private set; }

    public double? ActualDistanceKm { get; private set; }

    public int? ActualDurationMin { get; private set; }

    public VehicleType VehicleType { get; private set; }

    public decimal Fare { get; private set; }

    public decimal PlatformBookingFee { get; private set; }

    public decimal TotalAmount { get; private set; }

    public PaymentMethod PaymentMethod { get; private set; } = PaymentMethod.Cash;

    public RideStatus Status { get; private set; } = RideStatus.Requested;

    public DateTimeOffset RequestedAt { get; private set; }

    public DateTimeOffset? AcceptedAt { get; private set; }

    public DateTimeOffset? DriverAssignedAt { get; private set; }

    public DateTimeOffset? ArrivedAtPickupAt { get; private set; }

    public DateTimeOffset? StartedAt { get; private set; }

    public DateTimeOffset? CompletedAt { get; private set; }

    public DateTimeOffset? CancelledAt { get; private set; }

    public string? CancelReason { get; private set; }

    public CancelledBy? CancelledBy { get; private set; }

    public decimal CancellationFee { get; private set; }

    public bool IsSos { get; private set; }

    public decimal SosDriverPayout { get; private set; }

    public decimal PlatformEmergencyFee { get; private set; }

    // Surge pricing fields
    public decimal SurgeMultiplier { get; private set; } = 1.0m;

    public string? SurgeReason { get; private set; }

    public decimal BaseFare { get; private set; }

    public decimal DistanceFare { get; private set; }

    public decimal TimeFare { get; private set; }

    // OTP verification
    public string? OtpCode { get; private set; }

    public DateTimeOffset? OtpVerifiedAt { get; private set; }

    // Two-way ratings
    public int? RatingByRider { get; private set; }

    public int? RatingByDriver { get; private set; }

    public string? RiderFeedback { get; private set; }

    public string? DriverFeedback { get; private set; }

    // Live trip sharing
    public Guid? TripShareToken { get; private set; }

    private RideRequest()
    {
    }

    public static RideRequest Create(
        Guid userId,
        GeoLocation pickupLocation,
        string pickupAddress,
        GeoLocation dropoffLocation,
        string dropoffAddress,
        double distanceKm,
        int estimatedDurationMin,
        VehicleType vehicleType,
        decimal fare,
        PaymentMethod paymentMethod,
        bool isSos = false,
        decimal sosDriverPayout = 0m,
        decimal platformEmergencyFee = 0m,
        decimal surgeMultiplier = 1.0m,
        string? surgeReason = null,
        decimal baseFare = 0m,
        decimal distanceFare = 0m,
        decimal timeFare = 0m)
    {
        if (userId == Guid.Empty)
            throw new ArgumentException("User ID is required.", nameof(userId));
        ArgumentException.ThrowIfNullOrWhiteSpace(pickupAddress);
        ArgumentException.ThrowIfNullOrWhiteSpace(dropoffAddress);
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(distanceKm, nameof(distanceKm));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(fare, nameof(fare));

        var platformBookingFee = isSos ? platformEmergencyFee : 15m;
        var totalAmount = isSos ? fare : fare + 15m;

        return new RideRequest
        {
            UserId = userId,
            PickupLocation = pickupLocation,
            PickupAddress = pickupAddress,
            DropoffLocation = dropoffLocation,
            DropoffAddress = dropoffAddress,
            DistanceKm = distanceKm,
            EstimatedDurationMin = estimatedDurationMin,
            VehicleType = vehicleType,
            Fare = fare,
            PlatformBookingFee = platformBookingFee,
            TotalAmount = totalAmount,
            PaymentMethod = paymentMethod,
            RequestedAt = DateTimeOffset.UtcNow,
            Status = RideStatus.Requested,
            IsSos = isSos,
            SosDriverPayout = sosDriverPayout,
            PlatformEmergencyFee = platformEmergencyFee,
            SurgeMultiplier = surgeMultiplier,
            SurgeReason = surgeReason,
            BaseFare = baseFare,
            DistanceFare = distanceFare,
            TimeFare = timeFare
        };
    }

    /// <summary>
    /// Transition to Searching state when dispatch engine begins matching.
    /// </summary>
    public void StartSearching()
    {
        if (Status != RideStatus.Requested)
            throw new InvalidOperationException("Only newly requested rides can start searching.");
        Status = RideStatus.Searching;
        MarkUpdated();
    }

    /// <summary>
    /// Mark as no drivers available after dispatch exhausts all options.
    /// </summary>
    public void MarkNoDriversAvailable()
    {
        if (Status != RideStatus.Searching)
            throw new InvalidOperationException("Only searching rides can be marked as no drivers available.");
        Status = RideStatus.NoDriversAvailable;
        MarkUpdated();
    }

    /// <summary>
    /// Assign a driver to the ride (by dispatch engine). Generates OTP for verification.
    /// Replaces the old Accept method for the new dispatch flow.
    /// </summary>
    public void AssignDriver(Guid driverId, string otpCode)
    {
        if (Status is not (RideStatus.Searching or RideStatus.Requested))
            throw new InvalidOperationException("Ride is no longer available for driver assignment.");

        DriverId = driverId;
        OtpCode = otpCode;
        Status = RideStatus.DriverAssigned;
        DriverAssignedAt = DateTimeOffset.UtcNow;
        AcceptedAt ??= DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Legacy accept method — kept for backward compatibility with existing
    /// tests and the old first-come broadcast flow. New code should use AssignDriver.
    /// </summary>
    public void Accept(Guid driverId)
    {
        if (Status is not (RideStatus.Requested or RideStatus.Searching or RideStatus.NoDriversAvailable))
            throw new InvalidOperationException("Ride is no longer available.");
        DriverId = driverId;
        Status = RideStatus.Accepted;
        AcceptedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Driver has arrived at the pickup location.
    /// </summary>
    public void ArriveAtPickup()
    {
        if (Status is not (RideStatus.DriverAssigned or RideStatus.Accepted))
            throw new InvalidOperationException("Driver must be assigned before arriving at pickup.");
        Status = RideStatus.ArrivedAtPickup;
        ArrivedAtPickupAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Verify the OTP and start the ride (driver enters OTP shown by rider).
    /// </summary>
    public void VerifyOtpAndStart(string otp)
    {
        if (Status is not (RideStatus.DriverAssigned or RideStatus.Accepted or RideStatus.ArrivedAtPickup))
            throw new InvalidOperationException("Ride must have a driver assigned before starting.");

        if (OtpCode is not null && !string.Equals(OtpCode, otp, StringComparison.Ordinal))
            throw new InvalidOperationException("Invalid OTP. Please verify with the rider.");

        OtpVerifiedAt = DateTimeOffset.UtcNow;
        Status = RideStatus.EnRoute;
        StartedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Legacy start method — kept for backward compatibility. Starts ride without OTP.
    /// </summary>
    public void StartRide()
    {
        if (Status is not (RideStatus.Accepted or RideStatus.ArrivedAtPickup))
            throw new InvalidOperationException("Only accepted or arrived rides can start.");
        Status = RideStatus.EnRoute;
        StartedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Complete the ride with actual distance and duration metrics.
    /// </summary>
    public void CompleteWithMetrics(double actualDistanceKm, int actualDurationMin)
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled)
            throw new InvalidOperationException("Ride already completed or cancelled.");
        if (Status != RideStatus.EnRoute)
            throw new InvalidOperationException("Only en-route rides can be completed.");

        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(actualDistanceKm, nameof(actualDistanceKm));
        ArgumentOutOfRangeException.ThrowIfNegativeOrZero(actualDurationMin, nameof(actualDurationMin));

        ActualDistanceKm = actualDistanceKm;
        ActualDurationMin = actualDurationMin;
        Status = RideStatus.Completed;
        CompletedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Legacy complete method — kept for backward compatibility.
    /// </summary>
    public void Complete()
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled)
            throw new InvalidOperationException("Ride already completed or cancelled.");
        if (Status != RideStatus.EnRoute)
            throw new InvalidOperationException("Only en-route rides can be completed.");
        Status = RideStatus.Completed;
        CompletedAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Cancel the ride by the rider. Applies cancellation fee based on current state.
    /// </summary>
    public void CancelByRider(string? reason = null)
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled)
            throw new InvalidOperationException("Ride already completed or cancelled.");

        CancellationFee = CalculateCancellationFee();
        CancelledBy = Enums.CancelledBy.Rider;
        CancelReason = reason;
        Status = RideStatus.Cancelled;
        CancelledAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Cancel the ride by the driver (post-assignment). Triggers reassignment flow.
    /// Sets status to DriverCancelled so dispatch engine can re-dispatch.
    /// </summary>
    public void CancelByDriver(string? reason = null)
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled or RideStatus.EnRoute)
            throw new InvalidOperationException("Cannot cancel an ongoing or completed ride as driver.");

        CancelledBy = Enums.CancelledBy.Driver;
        CancelReason = reason;
        Status = RideStatus.DriverCancelled;
        CancelledAt = DateTimeOffset.UtcNow;
        MarkUpdated();
    }

    /// <summary>
    /// Legacy cancel method — kept for backward compatibility. Cancels by rider.
    /// </summary>
    public void Cancel(string? reason = null)
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled)
            throw new InvalidOperationException("Ride already completed or cancelled.");
        CancelledBy = Enums.CancelledBy.Rider;
        Status = RideStatus.Cancelled;
        CancelledAt = DateTimeOffset.UtcNow;
        CancelReason = reason;
        MarkUpdated();
    }

    /// <summary>
    /// System cancellation (e.g. timeout with no drivers). No fee charged.
    /// </summary>
    public void CancelBySystem(string? reason = null)
    {
        if (Status is RideStatus.Completed or RideStatus.Cancelled)
            throw new InvalidOperationException("Ride already completed or cancelled.");

        CancelledBy = Enums.CancelledBy.System;
        CancelReason = reason;
        Status = RideStatus.Cancelled;
        CancelledAt = DateTimeOffset.UtcNow;
        CancellationFee = 0m;
        MarkUpdated();
    }

    /// <summary>
    /// Reassign to a new driver after previous driver cancelled.
    /// Resets to Searching state and clears driver-specific fields.
    /// </summary>
    public void ReassignForDispatch()
    {
        if (Status != RideStatus.DriverCancelled && Status != RideStatus.NoDriversAvailable)
            throw new InvalidOperationException("Only driver-cancelled or no-drivers-available rides can be reassigned.");

        DriverId = null;
        OtpCode = null;
        OtpVerifiedAt = null;
        DriverAssignedAt = null;
        ArrivedAtPickupAt = null;
        Status = RideStatus.Searching;
        MarkUpdated();
    }

    /// <summary>
    /// Rider rates the driver after completion.
    /// </summary>
    public void RateByRider(int rating, string? feedback = null)
    {
        if (Status != RideStatus.Completed)
            throw new InvalidOperationException("Can only rate completed rides.");
        ArgumentOutOfRangeException.ThrowIfLessThan(rating, 1, nameof(rating));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(rating, 5, nameof(rating));

        RatingByRider = rating;
        RiderFeedback = feedback;
        MarkUpdated();
    }

    /// <summary>
    /// Driver rates the rider after completion.
    /// </summary>
    public void RateByDriver(int rating, string? feedback = null)
    {
        if (Status != RideStatus.Completed)
            throw new InvalidOperationException("Can only rate completed rides.");
        ArgumentOutOfRangeException.ThrowIfLessThan(rating, 1, nameof(rating));
        ArgumentOutOfRangeException.ThrowIfGreaterThan(rating, 5, nameof(rating));

        RatingByDriver = rating;
        DriverFeedback = feedback;
        MarkUpdated();
    }

    /// <summary>
    /// Generate a trip share token for live trip sharing with contacts.
    /// </summary>
    public Guid EnableTripSharing()
    {
        TripShareToken ??= Guid.NewGuid();
        MarkUpdated();
        return TripShareToken.Value;
    }

    /// <summary>
    /// Calculate cancellation fee based on current ride state.
    /// Free within 2 minutes of request or before driver assigned.
    /// ₹25 if driver assigned and en route. ₹50 if driver arrived (no-show).
    /// </summary>
    public decimal CalculateCancellationFee()
    {
        // Free if no driver assigned yet
        if (Status is RideStatus.Requested or RideStatus.Searching or RideStatus.NoDriversAvailable)
            return 0m;

        // Free within 60 seconds of request (cancellation grace period)
        if ((DateTimeOffset.UtcNow - RequestedAt).TotalSeconds < 60)
            return 0m;

        // ₹50 if driver arrived at pickup (rider no-show)
        if (Status == RideStatus.ArrivedAtPickup)
            return 50m;

        // ₹25 if driver assigned and en route to pickup
        if (Status is RideStatus.DriverAssigned or RideStatus.Accepted)
            return 25m;

        return 0m;
    }
}
