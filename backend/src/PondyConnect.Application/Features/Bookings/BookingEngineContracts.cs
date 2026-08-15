namespace PondyConnect.Application.Features.Bookings;

using PondyConnect.Domain.Enums;

/// <summary>
/// High-concurrency booking engine responsible for zero-overbooking venue
/// pass sales, idempotent payment reconciliation and atomic bundle rollback.
/// All operations run inside a distributed lock (Redis) and an explicit
/// Serializable Postgres transaction.
/// </summary>
public interface IBookingEngineService
{
    Task<VenueSlotReservationResult> ReserveVenueSlotAsync(
        ReserveVenueSlotRequest request,
        CancellationToken cancellationToken = default);

    Task<PaymentReconciliationResult> ReconcilePaymentAsync(
        ReconcilePaymentRequest request,
        CancellationToken cancellationToken = default);

    Task<BundleReservationResult> ReserveBundleAsync(
        ReserveBundleRequest request,
        CancellationToken cancellationToken = default);
}

public sealed record ReserveVenueSlotRequest(
    Guid VenueId,
    Guid UserId,
    int Seats,
    DateTimeOffset ScheduledFor,
    string? Notes = null);

public sealed record VenueSlotReservationResult(
    Guid BookingId,
    decimal Amount,
    string Status,
    string PassToken);

public sealed record ReconcilePaymentRequest(
    string ProviderOrderId,
    string ProviderPaymentId);

public sealed record PaymentReconciliationResult(
    Guid PaymentId,
    Guid? ServiceBookingId,
    string PassToken,
    bool AlreadyReconciled);

public sealed record ReserveBundleRequest(
    Guid UserId,
    Guid VenueId,
    int VenueSeats,
    DateTimeOffset ScheduledFor,
    ReserveTransitLeg? TransitLeg = null,
    ReserveLuggageLeg? LuggageLeg = null);

public sealed record ReserveTransitLeg(
    Guid HubId,
    string ArrivalFrom,
    string ArrivalMode,
    DateTimeOffset ArrivalAt,
    int PartySize,
    decimal Price);

public sealed record ReserveLuggageLeg(
    Guid VendorId,
    DateTimeOffset ScheduledFor,
    DateTimeOffset DroppedAt,
    int BagCount,
    decimal RatePerHour);

public sealed record BundleReservationResult(
    Guid BookingId,
    Guid? TransitTripId,
    Guid? LuggageDropOffId,
    string Status,
    string PassToken);