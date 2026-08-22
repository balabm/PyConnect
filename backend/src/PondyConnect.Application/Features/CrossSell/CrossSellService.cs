namespace PondyConnect.Application.Features.CrossSell;

using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;
using System.Globalization;

/// <summary>
/// Cross-pollination engine that generates ride upsell suggestions
/// after a user books an event at a venue. The suggestion pre-fills
/// the venue's GPS coordinates as the drop-off and schedules the ride
/// 30 minutes before the event starts, with a 15% discount.
/// </summary>
public sealed class CrossSellService
{
    /// <summary>
    /// Discount applied to cross-sell rides (15%).
    /// </summary>
    public const decimal RideDiscountPercent = 15m;

    /// <summary>
    /// Minutes before the event to schedule the pickup.
    /// </summary>
    public const int PickupMinutesBeforeEvent = 30;

    private readonly IApplicationDbContext _context;
    private readonly ILogger<CrossSellService> _logger;

    public CrossSellService(
        IApplicationDbContext context,
        ILogger<CrossSellService> logger)
    {
        _context = context;
        _logger = logger;
    }

    /// <summary>
    /// Generates a ride upsell suggestion for a confirmed booking.
    /// Returns null if the booking doesn't have a venue with GPS coordinates.
    /// </summary>
    public async Task<RideUpsellSuggestion?> GetRideUpsellAsync(
        Guid bookingId,
        CancellationToken ct = default)
    {
        var booking = await _context.ServiceBookings
            .AsNoTracking()
            .FirstOrDefaultAsync(b => b.Id == bookingId, ct);

        if (booking is null || booking.Status != BookingStatus.Confirmed)
            return null;

        if (!booking.VenueId.HasValue)
            return null;

        var venue = await _context.Venues
            .AsNoTracking()
            .FirstOrDefaultAsync(v => v.Id == booking.VenueId.Value, ct);

        if (venue is null || venue.Location is null)
            return null;

        // Schedule pickup 30 minutes before the event
        var pickupTime = booking.ScheduledFor.AddMinutes(-PickupMinutesBeforeEvent);

        // Only suggest if the event is in the future
        if (pickupTime <= DateTimeOffset.UtcNow)
            return null;

        return new RideUpsellSuggestion(
            BookingId: booking.Id,
            VenueName: venue.Name,
            DropoffLatitude: venue.Location.Latitude,
            DropoffLongitude: venue.Location.Longitude,
            PickupTime: pickupTime,
            EventTime: booking.ScheduledFor,
            DiscountPercent: RideDiscountPercent,
            DiscountText: $"{RideDiscountPercent.ToString("F0", CultureInfo.InvariantCulture)}% off your ride");
    }
}

public sealed record RideUpsellSuggestion(
    Guid BookingId,
    string VenueName,
    double DropoffLatitude,
    double DropoffLongitude,
    DateTimeOffset PickupTime,
    DateTimeOffset EventTime,
    decimal DiscountPercent,
    string DiscountText);
