namespace PondyConnect.Application.Features.Bookings;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Application.Features.Settlement;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Implements the core transaction &amp; concurrency protocol.
///
/// - <b>Distributed lock</b>: every capacity-limited reservation acquires a
///   Redis lock scoped to the venue before reading/writing capacity, so
///   concurrent flash-sale bookings cannot interleave a read-modify-write.
/// - <b>Atomic state transitions</b>: all mutations across ServiceBooking,
///   Venue, TransitTrip and LuggageDropOff run inside an explicit
///   Serializable Postgres transaction that is rolled back unless the whole
///   bundle commits.
/// - <b>Idempotent payment reconcile</b>: replaying the same provider payment
///   yields the already-issued pass instead of double-charging.
/// </summary>
public sealed class BookingEngineService : IBookingEngineService
{
    private const string LockPrefix = "venue:slot";
    private static readonly TimeSpan s_leaseDuration = TimeSpan.FromSeconds(30);
    private static readonly TimeSpan s_waitTimeout = TimeSpan.FromSeconds(5);

    private readonly IApplicationDbContext _context;
    private readonly IDistributedLock _lock;
    private readonly IAvailabilityCache _availabilityCache;
    private readonly ISettlementCalculationService _settlementService;
    private readonly IWhatsAppSender? _whatsAppSender;

    public BookingEngineService(
        IApplicationDbContext context,
        IDistributedLock distributedLock,
        IAvailabilityCache availabilityCache,
        ISettlementCalculationService settlementService)
    {
        _context = context;
        _lock = distributedLock;
        _availabilityCache = availabilityCache;
        _settlementService = settlementService;
        _whatsAppSender = null;
    }

    public BookingEngineService(
        IApplicationDbContext context,
        IDistributedLock distributedLock,
        IAvailabilityCache availabilityCache,
        ISettlementCalculationService settlementService,
        IWhatsAppSender whatsAppSender)
    {
        _context = context;
        _lock = distributedLock;
        _availabilityCache = availabilityCache;
        _settlementService = settlementService;
        _whatsAppSender = whatsAppSender;
    }

    public async Task<VenueSlotReservationResult> ReserveVenueSlotAsync(
        ReserveVenueSlotRequest request,
        CancellationToken cancellationToken = default)
    {
        await using var lease = await _lock.TryAcquireAsync(
            $"{LockPrefix}:{request.VenueId}",
            s_leaseDuration,
            s_waitTimeout,
            cancellationToken)
            ?? throw new BookingConflictException($"Venue is at full capacity.");

        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);

        try
        {
            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.IsActive, cancellationToken)
                ?? throw new InvalidOperationException("Venue not found or is not active.");

            // Prevent the same user from double-booking the same venue at the same time.
            var existingUserBooking = await _context.ServiceBookings
                .AnyAsync(b => b.VenueId == request.VenueId
                    && b.UserId == request.UserId
                    && b.ScheduledFor == request.ScheduledFor
                    && (b.Status == BookingStatus.Pending
                        || b.Status == BookingStatus.Confirmed
                        || b.Status == BookingStatus.CheckedIn), cancellationToken);

            if (existingUserBooking)
                throw new BookingConflictException("You already have a booking for this venue at the selected time.");

            if (!venue.HasAvailability(request.Seats))
                throw new BookingConflictException($"Venue '{venue.Name}' is at full capacity.");

            var booking = ServiceBooking.Create(
                userId: request.UserId,
                serviceType: ServiceType.Nightlife,
                scheduledFor: request.ScheduledFor,
                amount: 0m,
                notes: request.Notes,
                venueId: request.VenueId,
                seatCount: request.Seats);

            booking.AddItem("Venue cover charge", request.Seats, CoverChargeFor(venue));

            venue.IncreaseOccupancy(request.Seats);

            _context.ServiceBookings.Add(booking);
            var saved = await _context.SaveChangesAsync(cancellationToken);

            var pass = PassIssuer.Issue(booking.Id, booking.TotalAmount, request.ScheduledFor);
            booking.IssuePassToken(pass);
            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            if (transaction is null || saved > 0)
            {
                await _availabilityCache.SetVenueOccupancyAsync(
                    venue.Id,
                    venue.CurrentCapacity,
                    TimeSpan.FromMinutes(5),
                    cancellationToken);
            }

            return new VenueSlotReservationResult(
                booking.Id,
                booking.TotalAmount,
                booking.Status.ToString(),
                pass);
        }
        catch
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    public async Task<PaymentReconciliationResult> ReconcilePaymentAsync(
        ReconcilePaymentRequest request,
        CancellationToken cancellationToken = default)
    {
        // Idempotency: bail early when the payment is already captured.
        var existing = await _context.Payments
            .FirstOrDefaultAsync(p => p.ProviderOrderId == request.ProviderOrderId, cancellationToken);
        if (existing?.Status == PaymentStatus.Captured)
        {
            var bookingId = existing.ServiceBookingId;
            var pass = string.Empty;
            if (bookingId is { } bid)
            {
                var bookingForPass = await _context.ServiceBookings
                    .AsNoTracking()
                    .FirstOrDefaultAsync(b => b.Id == bid, cancellationToken);
                if (bookingForPass is not null)
                    pass = bookingForPass.PassToken ?? PassIssuer.Issue(bookingForPass.Id, bookingForPass.TotalAmount, bookingForPass.ScheduledFor);
            }
            return new PaymentReconciliationResult(
                existing.Id,
                bookingId,
                pass,
                AlreadyReconciled: true);
        }

        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);
        try
        {
            var payment = await _context.Payments
                .FirstOrDefaultAsync(p => p.ProviderOrderId == request.ProviderOrderId, cancellationToken)
                ?? throw new InvalidOperationException("Payment intent not found.");

            payment.MarkCaptured(request.ProviderPaymentId);

            if (payment.ServiceBookingId is { } bookingId)
            {
                var booking = await _context.ServiceBookings
                    .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

                if (booking is not null)
                {
                    booking.RecordPayment(PaymentStatus.Captured, request.ProviderPaymentId);
                    booking.Confirm();
                }
            }

            // Financial settlement: compute the vendor/driver/platform split
            // and persist a PaymentSettlement record within the same atomic
            // transaction as the payment capture and booking confirmation.
            var settlement = await _settlementService.CalculateSettlementAsync(payment.Id, cancellationToken);
            var settlementRecord = PaymentSettlement.Create(
                paymentId: payment.Id,
                grossAmount: settlement.GrossAmount,
                vendorPayout: settlement.VendorPayout,
                driverPayout: settlement.DriverPayout,
                platformFee: settlement.PlatformFee,
                serviceBookingId: settlement.ServiceBookingId,
                foodOrderId: settlement.FoodOrderId,
                rideRequestId: settlement.RideRequestId,
                scooterRentalId: settlement.ScooterRentalId);
            _context.PaymentSettlements.Add(settlementRecord);

            // Backfill pass token on the booking if missing (inside transaction)
            var passToken = string.Empty;
            if (payment.ServiceBookingId is { } bid)
            {
                var bookingForPass = await _context.ServiceBookings
                    .FirstOrDefaultAsync(b => b.Id == bid, cancellationToken);
                if (bookingForPass is not null)
                {
                    passToken = bookingForPass.PassToken ?? PassIssuer.Issue(bookingForPass.Id, bookingForPass.TotalAmount, bookingForPass.ScheduledFor);
                    if (bookingForPass.PassToken is null)
                        bookingForPass.IssuePassToken(passToken);
                }
            }

            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            // Fire-and-forget WhatsApp booking confirmation so the HTTP
            // response to the Flutter app is not delayed by the Meta API call.
            if (_whatsAppSender is not null && !string.IsNullOrWhiteSpace(passToken))
            {
                _ = SendWhatsAppConfirmationAsync(payment, passToken, cancellationToken);
            }

            return new PaymentReconciliationResult(
                payment.Id,
                payment.ServiceBookingId,
                passToken,
                AlreadyReconciled: false);
        }
        catch
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    /// <summary>
    /// Resolves the user's phone and service type from the payment/booking
    /// and dispatches the WhatsApp confirmation message. All exceptions are
    /// swallowed so a Meta API failure never surfaces to the caller.
    /// </summary>
    private async Task SendWhatsAppConfirmationAsync(
        Payment payment,
        string passToken,
        CancellationToken cancellationToken)
    {
        if (_whatsAppSender is null) return;

        try
        {
            string? userPhone = null;
            string serviceType = "Booking";

            if (payment.ServiceBookingId is { } bookingId)
            {
                var booking = await _context.ServiceBookings
                    .AsNoTracking()
                    .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

                if (booking is not null)
                {
                    var user = await _context.Users
                        .AsNoTracking()
                        .FirstOrDefaultAsync(u => u.Id == booking.UserId, cancellationToken);

                    userPhone = user?.Phone;
                    serviceType = booking.ServiceType.ToString();
                }
            }

            if (string.IsNullOrWhiteSpace(userPhone))
                return;

            // Ensure international format for Meta Graph API
            var normalizedPhone = userPhone.TrimStart('+');
            if (!normalizedPhone.StartsWith("91", StringComparison.Ordinal) && normalizedPhone.Length == 10)
                normalizedPhone = "91" + normalizedPhone;

            await _whatsAppSender.SendBookingConfirmationAsync(
                normalizedPhone,
                serviceType,
                passToken,
                CancellationToken.None);
        }
        catch
        {
            // Best-effort delivery — never crash the reconciliation flow.
        }
    }

    public async Task<BundleReservationResult> ReserveBundleAsync(
        ReserveBundleRequest request,
        CancellationToken cancellationToken = default)
    {
        // A bundle spans multiple venues/workflows; use a per-user lock so
        // retries of the same bundle cannot interleave.
        await using var lease = await _lock.TryAcquireAsync(
            $"bundle:{request.UserId}",
            s_leaseDuration,
            s_waitTimeout,
            cancellationToken) ?? throw new InvalidOperationException("Bundle booking is busy, retry in a moment.");

        await using var transaction = await _context.BeginTransactionAsync(cancellationToken);

        try
        {
            var venue = await _context.Venues
                .FirstOrDefaultAsync(v => v.Id == request.VenueId && v.IsActive, cancellationToken)
                ?? throw new InvalidOperationException("Venue not found or is not active.");

            if (!venue.HasAvailability(request.VenueSeats))
                throw new InvalidOperationException($"Venue '{venue.Name}' is at full capacity.");

            venue.IncreaseOccupancy(request.VenueSeats);

            var booking = ServiceBooking.Create(
                userId: request.UserId,
                serviceType: ServiceType.Nightlife,
                scheduledFor: request.ScheduledFor,
                amount: 0m,
                venueId: request.VenueId,
                seatCount: request.VenueSeats);

            booking.AddItem("Venue cover pass", request.VenueSeats, CoverChargeFor(venue));

            TransitTrip? trip = null;
            LuggageDropOff? luggage = null;

            if (request.TransitLeg is not null)
            {
                var hubExists = await _context.TransitHubs.AnyAsync(h => h.Id == request.TransitLeg.HubId, cancellationToken);
                if (!hubExists)
                    throw new InvalidOperationException("Transit hub not found.");

                trip = TransitTrip.Create(
                    userId: request.UserId,
                    hubId: request.TransitLeg.HubId,
                    arrivalFrom: request.TransitLeg.ArrivalFrom,
                    arrivalMode: request.TransitLeg.ArrivalMode,
                    arrivalAt: request.TransitLeg.ArrivalAt,
                    partySize: request.TransitLeg.PartySize,
                    price: request.TransitLeg.Price);

                booking.AddItem(
                    $"Transit pickup from {request.TransitLeg.ArrivalFrom}",
                    request.TransitLeg.PartySize,
                    request.TransitLeg.Price);

                _context.TransitTrips.Add(trip);
            }

            if (request.LuggageLeg is not null)
            {
                var vendorExists = await _context.Vendors.AnyAsync(
                    v => v.Id == request.LuggageLeg.VendorId, cancellationToken);
                if (!vendorExists)
                    throw new InvalidOperationException("Luggage vendor not found.");

                luggage = LuggageDropOff.Create(
                    userId: request.UserId,
                    vendorId: request.LuggageLeg.VendorId,
                    scheduledFor: request.LuggageLeg.ScheduledFor,
                    droppedAt: request.LuggageLeg.DroppedAt,
                    bagCount: request.LuggageLeg.BagCount,
                    ratePerHour: request.LuggageLeg.RatePerHour);

                booking.AddItem(
                    "Luggage cloak",
                    request.LuggageLeg.BagCount,
                    request.LuggageLeg.RatePerHour);

                _context.LuggageDropOffs.Add(luggage);
            }

            _context.ServiceBookings.Add(booking);
            await _context.SaveChangesAsync(cancellationToken);

            var pass = PassIssuer.Issue(booking.Id, booking.TotalAmount, request.ScheduledFor);
            booking.IssuePassToken(pass);
            await _context.SaveChangesAsync(cancellationToken);

            if (transaction is not null)
                await transaction.CommitAsync(cancellationToken);

            await _availabilityCache.SetVenueOccupancyAsync(
                venue.Id,
                venue.CurrentCapacity,
                TimeSpan.FromMinutes(5),
                cancellationToken);

            return new BundleReservationResult(
                booking.Id,
                trip?.Id,
                luggage?.Id,
                booking.Status.ToString(),
                pass);
        }
        catch
        {
            if (transaction is not null)
                await transaction.RollbackAsync(cancellationToken);
            throw;
        }
    }

    private static decimal CoverChargeFor(Venue venue) => venue switch
    {
        { Category: VenueCategory.Club } => 500m,
        { Category: VenueCategory.Pub } => 200m,
        { Category: VenueCategory.Bar } => 150m,
        _ => 100m
    };
}

/// <summary>
/// Deterministic, short-lived QR pass payload for a booking. The issuer is
/// kept stateless so a reconciliation retry reproduces the exact same code.
/// </summary>
public static class PassIssuer
{
    private static readonly System.Security.Cryptography.HMACSHA256 s_hmac =
        new(System.Text.Encoding.UTF8.GetBytes("pondyconnect-pass-v1"));

    public static string Issue(Guid bookingId, decimal amount, DateTimeOffset scheduledFor)
    {
        var raw = System.Text.Encoding.UTF8.GetBytes($"{bookingId:N}|{amount:F2}|{scheduledFor:O}");
        var hash = s_hmac.ComputeHash(raw);
        return Convert.ToBase64String(hash).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }

}

/// <summary>
/// Signals a capacity conflict (a contender lost the slot race).
/// </summary>
public sealed class BookingConflictException : InvalidOperationException
{
    public BookingConflictException(string message) : base(message)
    {
    }
}