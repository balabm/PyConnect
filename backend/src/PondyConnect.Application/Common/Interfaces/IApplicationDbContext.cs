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

    DbSet<ModifierGroup> ModifierGroups { get; }

    DbSet<Modifier> Modifiers { get; }

    DbSet<Product> Products { get; }

    DbSet<ProductOrder> ProductOrders { get; }

    DbSet<ProductOrderItem> ProductOrderItems { get; }

    DbSet<Driver> Drivers { get; }

    DbSet<RideRequest> RideRequests { get; }

    DbSet<WaitlistEntry> WaitlistEntries { get; }

    DbSet<UserWallet> UserWallets { get; }

    DbSet<UserWalletTransaction> UserWalletTransactions { get; }

    DbSet<Referral> Referrals { get; }

    DbSet<VendorLedgerEntry> VendorLedgerEntries { get; }

    DbSet<TaxInvoice> TaxInvoices { get; }

    DbSet<LedgerEntry> LedgerEntries { get; }

    DbSet<PayoutRequest> PayoutRequests { get; }

    DbSet<ChargebackDispute> ChargebackDisputes { get; }

    DbSet<DineInSession> DineInSessions { get; }

    DbSet<SubscriptionPlan> SubscriptionPlans { get; }

    DbSet<UserSubscription> UserSubscriptions { get; }

    DbSet<PaymentSettlement> PaymentSettlements { get; }

    DbSet<DriverLedgerEntry> DriverLedgerEntries { get; }

    DbSet<DriverWallet> DriverWallets { get; }

    DbSet<DriverWalletTransaction> DriverWalletTransactions { get; }

    DbSet<DriverWithdrawal> DriverWithdrawals { get; }

    DbSet<DriverVehicle> DriverVehicles { get; }

    DbSet<DriverPreferences> DriverPreferences { get; }

    DbSet<DispatchTask> DispatchTasks { get; }

    DbSet<Homestay> Homestays { get; }

    DbSet<RoomAvailability> RoomAvailabilities { get; }

    DbSet<SupportTicket> SupportTickets { get; }

    DbSet<DisputeTicket> DisputeTickets { get; }

    DbSet<TicketMessage> TicketMessages { get; }

    DbSet<AdminActionLog> AdminActionLogs { get; }

    DbSet<AppEventLog> AppEventLogs { get; }

    DbSet<RideEvent> RideEvents { get; }

    DbSet<EmergencyContact> EmergencyContacts { get; }

    DbSet<SosAlert> SosAlerts { get; }

    DbSet<SavedLocation> SavedLocations { get; }

    DbSet<UserAddress> UserAddresses { get; }

    DbSet<ScheduledRide> ScheduledRides { get; }

    DbSet<Review> Reviews { get; }

    DbSet<ProcessedWebhook> ProcessedWebhooks { get; }

    DbSet<ConsumerFlag> ConsumerFlags { get; }

    DbSet<GuestKyc> GuestKycs { get; }

    // ── Party Ecosystem ──
    DbSet<EquipmentItem> EquipmentItems { get; }
    DbSet<EquipmentRental> EquipmentRentals { get; }
    DbSet<P2pEvent> P2pEvents { get; }
    DbSet<P2pEventTicket> P2pEventTickets { get; }
    DbSet<DoorLogEntry> DoorLogEntries { get; }
    DbSet<EquipmentMaintenanceBlock> EquipmentMaintenanceBlocks { get; }
    DbSet<VendorStaff> VendorStaffs { get; }

    // ── Party Services Marketplace ──
    DbSet<PartyService> PartyServices { get; }
    DbSet<PartyServiceBooking> PartyServiceBookings { get; }
    DbSet<GuestlistEntry> GuestlistEntries { get; }
    DbSet<ScooterFleetItem> ScooterFleetItems { get; }

    // ── Split Payments (P2P) ──
    DbSet<SplitPaymentPool> SplitPaymentPools { get; }
    DbSet<SplitPaymentContributor> SplitPaymentContributors { get; }

    // ── Genie Engine ──

    DbSet<GenieErrand> GenieErrands { get; }

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

    /// <summary>
    /// Acquires a pessimistic row-level lock (<c>SELECT ... FOR UPDATE</c>)
    /// on the specified row within the current transaction. Only effective on
    /// PostgreSQL; a no-op on other providers (SQLite/in-memory rely on the
    /// Serializable transaction + distributed lock). The lock is held until
    /// the enclosing transaction commits or rolls back.
    /// </summary>
    /// <param name="tableName">The database table name to lock a row in.</param>
    /// <param name="rowId">The primary key value of the row to lock.</param>
    Task AcquireRowLockAsync(string tableName, Guid rowId, CancellationToken cancellationToken = default);
}