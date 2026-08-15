namespace PondyConnect.Application.Features.Settlement;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;
using PondyConnect.Domain.Enums;

/// <summary>
/// Transparent zero-commission settlement engine. Computes the split
/// between vendor, driver and platform for each service stream:
///
/// - Food Delivery:  Vendor 100% food subtotal, Driver 100% delivery fee + bonus, Platform ₹0
/// - Scooter Rental: Vendor 100% daily rate (total − ₹50), Platform flat ₹50, Driver ₹0
/// - Ride-Hailing:   Driver 100% distance fare, Platform flat ₹15, Vendor ₹0
/// </summary>
public interface ISettlementCalculationService
{
    Task<SettlementResult> CalculateSettlementAsync(Guid paymentId, CancellationToken cancellationToken = default);
}

public sealed record SettlementResult(
    Guid PaymentId,
    decimal GrossAmount,
    decimal VendorPayout,
    decimal DriverPayout,
    decimal PlatformFee,
    Guid? ServiceBookingId,
    Guid? FoodOrderId,
    Guid? RideRequestId,
    Guid? ScooterRentalId);

public sealed class SettlementCalculationService : ISettlementCalculationService
{
    private const decimal RentalPlatformFee = 50m;
    private const decimal RidePlatformFee = 15m;

    private readonly IApplicationDbContext _context;

    public SettlementCalculationService(IApplicationDbContext context)
    {
        _context = context;
    }

    public async Task<SettlementResult> CalculateSettlementAsync(Guid paymentId, CancellationToken cancellationToken = default)
    {
        var payment = await _context.Payments
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == paymentId, cancellationToken)
            ?? throw new InvalidOperationException("Payment not found for settlement.");

        // Food delivery settlement — direct lookup via FoodOrderId FK
        if (payment.FoodOrderId is { } foodOrderId)
        {
            var foodOrder = await _context.FoodOrders
                .AsNoTracking()
                .FirstOrDefaultAsync(f => f.Id == foodOrderId, cancellationToken);

            if (foodOrder is not null)
            {
                var gross = payment.Amount;
                var vendorPayout = foodOrder.SubTotal;
                var driverPayout = foodOrder.DeliveryFee + foodOrder.LateNightDriverBonus;
                var platformFee = foodOrder.PlatformFee;

                return new SettlementResult(
                    payment.Id, gross, vendorPayout, driverPayout, platformFee,
                    null, foodOrderId, null, null);
            }
        }

        // Service booking settlement (nightlife/venue cover charges)
        if (payment.ServiceBookingId is { } bookingId)
        {
            var booking = await _context.ServiceBookings
                .AsNoTracking()
                .FirstOrDefaultAsync(b => b.Id == bookingId, cancellationToken);

            if (booking is not null)
            {
                // ServiceBooking covers nightlife/venue cover charges and
                // generic service bookings — vendor gets the full amount
                // minus any platform fee (₹0 for nightlife).
                var gross = payment.Amount;
                var vendorPayout = gross;
                var platformFee = 0m;
                var driverPayout = 0m;

                return new SettlementResult(
                    payment.Id, gross, vendorPayout, driverPayout, platformFee,
                    bookingId, null, null, null);
            }
        }

        // Scooter rental settlement
        if (payment.ScooterRentalId is { } rentalId)
        {
            var rental = await _context.ScooterRentals
                .AsNoTracking()
                .FirstOrDefaultAsync(r => r.Id == rentalId, cancellationToken);

            if (rental is not null)
            {
                var gross = payment.Amount;
                var platformFee = RentalPlatformFee;
                var vendorPayout = gross - platformFee;
                var driverPayout = 0m;

                return new SettlementResult(
                    payment.Id, gross, vendorPayout, driverPayout, platformFee,
                    null, null, null, rentalId);
            }
        }

        // Ride-hailing settlement
        if (payment.TransitTripId is not null)
        {
            // Transit trips are not ride-hailing; no settlement split needed.
            // Use a simple pass-through with zero platform fee.
            return new SettlementResult(
                payment.Id, payment.Amount, payment.Amount, 0m, 0m,
                null, null, null, null);
        }

        // Check for ride request via payment amount matching
        // (Payment doesn't have a direct RideRequestId FK, so we look up
        // by matching the payment amount to ride total amounts is not reliable.
        // Instead, we handle ride settlements when triggered from the
        // ReconcilePayment flow which passes context about the service type.)

        // Default: full amount to vendor, no platform fee
        return new SettlementResult(
            payment.Id, payment.Amount, payment.Amount, 0m, 0m,
            null, null, null, null);
    }

    /// <summary>
    /// Computes a settlement split for a ride-hailing payment. Called
    /// directly when the payment reconciliation flow knows the service type.
    /// </summary>
    public static SettlementResult CalculateForRide(Guid paymentId, Guid rideRequestId, decimal fare, decimal platformBookingFee)
    {
        return new SettlementResult(
            paymentId,
            fare + platformBookingFee,
            VendorPayout: 0m,
            DriverPayout: fare,
            PlatformFee: platformBookingFee,
            ServiceBookingId: null,
            FoodOrderId: null,
            RideRequestId: rideRequestId,
            ScooterRentalId: null);
    }

    /// <summary>
    /// Computes a settlement split for a food delivery payment. Called
    /// directly when the payment reconciliation flow knows the service type.
    /// </summary>
    public static SettlementResult CalculateForFoodOrder(Guid paymentId, Guid foodOrderId, decimal subTotal, decimal deliveryFee, decimal lateNightBonus, decimal platformFee)
    {
        return new SettlementResult(
            paymentId,
            subTotal + deliveryFee + lateNightBonus + platformFee,
            VendorPayout: subTotal,
            DriverPayout: deliveryFee + lateNightBonus,
            PlatformFee: platformFee,
            ServiceBookingId: null,
            FoodOrderId: foodOrderId,
            RideRequestId: null,
            ScooterRentalId: null);
    }

    /// <summary>
    /// Computes a settlement split for a scooter rental payment.
    /// </summary>
    public static SettlementResult CalculateForRental(Guid paymentId, Guid rentalId, decimal totalAmount)
    {
        return new SettlementResult(
            paymentId,
            totalAmount,
            VendorPayout: totalAmount - RentalPlatformFee,
            DriverPayout: 0m,
            PlatformFee: RentalPlatformFee,
            ServiceBookingId: null,
            FoodOrderId: null,
            RideRequestId: null,
            ScooterRentalId: rentalId);
    }
}
