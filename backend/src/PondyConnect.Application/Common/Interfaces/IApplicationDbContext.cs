namespace PondyConnect.Application.Common.Interfaces;

using Microsoft.EntityFrameworkCore;
using PondyConnect.Domain.Entities;

/// <summary>
/// Persistence contract consumed by application handlers. Implemented by EF
/// Core in the Infrastructure layer.
/// </summary>
public interface IApplicationDbContext
{
    DbSet<User> Users { get; }

    DbSet<Vendor> Vendors { get; }

    DbSet<Venue> Venues { get; }

    DbSet<TransitHub> TransitHubs { get; }

    DbSet<TransitTrip> TransitTrips { get; }

    DbSet<LuggageDropOff> LuggageDropOffs { get; }

    DbSet<ScooterRental> ScooterRentals { get; }

    DbSet<Payment> Payments { get; }

    DbSet<ServiceBooking> ServiceBookings { get; }

    DbSet<BookingItem> BookingItems { get; }

    DbSet<VenueAvailability> VenueAvailability { get; }

    DbSet<VendorPromotion> VendorPromotions { get; }

    DbSet<BundleBooking> BundleBookings { get; }

    DbSet<BundleItem> BundleItems { get; }

    DbSet<FoodOrder> FoodOrders { get; }

    DbSet<FoodOrderItem> FoodOrderItems { get; }

    DbSet<MenuItem> MenuItems { get; }

    DbSet<Product> Products { get; }

    DbSet<ProductOrder> ProductOrders { get; }

    DbSet<ProductOrderItem> ProductOrderItems { get; }

    DbSet<Driver> Drivers { get; }

    DbSet<RideRequest> RideRequests { get; }

    DbSet<WaitlistEntry> WaitlistEntries { get; }

    DbSet<UserWallet> UserWallets { get; }

    DbSet<PaymentSettlement> PaymentSettlements { get; }

    DbSet<DriverLedgerEntry> DriverLedgerEntries { get; }

    DbSet<DispatchTask> DispatchTasks { get; }

    DbSet<Homestay> Homestays { get; }

    DbSet<RoomAvailability> RoomAvailabilities { get; }

    DbSet<SupportTicket> SupportTickets { get; }

    DbSet<TicketMessage> TicketMessages { get; }

    DbSet<AdminActionLog> AdminActionLogs { get; }

    DbSet<AppEventLog> AppEventLogs { get; }

    DbSet<RideEvent> RideEvents { get; }

    DbSet<EmergencyContact> EmergencyContacts { get; }

    DbSet<SosAlert> SosAlerts { get; }

    DbSet<SavedLocation> SavedLocations { get; }

    DbSet<ScheduledRide> ScheduledRides { get; }

    DbSet<Review> Reviews { get; }

    Task<int> SaveChangesAsync(CancellationToken cancellationToken = default);

    /// <summary>
    /// True when the backing provider supports explicit transactions (Postgres
    /// in production). The in-memory provider used by tests returns false.
    /// </summary>
    bool IsTransactionSupported { get; }

    bool IsPostgreSQL { get; }

    /// <summary>
    /// Begins an explicit database transaction (Serializable in production) so
    /// competing bookings for the same venue cannot observe each other's
    /// intermediate capacity state. Returns null when the provider (e.g.
    /// in-memory) does not support transactions.
    /// </summary>
    Task<Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction?> BeginTransactionAsync(
        CancellationToken cancellationToken = default);
}