namespace PondyConnect.Infrastructure.Persistence;

using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;
using PondyConnect.Application.Common.Interfaces;
using PondyConnect.Domain.Entities;

public sealed class ApplicationDbContext : DbContext, IApplicationDbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
        : base(options)
    {
    }

    public DbSet<User> Users => Set<User>();

    public DbSet<Vendor> Vendors => Set<Vendor>();

    public DbSet<Venue> Venues => Set<Venue>();

    public DbSet<TransitHub> TransitHubs => Set<TransitHub>();

    public DbSet<TransitTrip> TransitTrips => Set<TransitTrip>();

    public DbSet<LuggageDropOff> LuggageDropOffs => Set<LuggageDropOff>();

    public DbSet<ScooterRental> ScooterRentals => Set<ScooterRental>();

    public DbSet<Payment> Payments => Set<Payment>();

    public DbSet<ServiceBooking> ServiceBookings => Set<ServiceBooking>();

    public DbSet<BookingItem> BookingItems => Set<BookingItem>();

    public DbSet<VenueAvailability> VenueAvailability => Set<VenueAvailability>();

    public DbSet<SubscriptionPlan> SubscriptionPlans => Set<SubscriptionPlan>();

    public DbSet<UserSubscription> UserSubscriptions => Set<UserSubscription>();

    public DbSet<VendorPromotion> VendorPromotions => Set<VendorPromotion>();

    public DbSet<BundleBooking> BundleBookings => Set<BundleBooking>();

    public DbSet<BundleItem> BundleItems => Set<BundleItem>();

    public DbSet<FoodOrder> FoodOrders => Set<FoodOrder>();

    public DbSet<FoodOrderItem> FoodOrderItems => Set<FoodOrderItem>();

    public DbSet<MenuItem> MenuItems => Set<MenuItem>();

    public DbSet<Product> Products => Set<Product>();

    public DbSet<ProductOrder> ProductOrders => Set<ProductOrder>();

    public DbSet<ProductOrderItem> ProductOrderItems => Set<ProductOrderItem>();

    public DbSet<Driver> Drivers => Set<Driver>();

    public DbSet<RideRequest> RideRequests => Set<RideRequest>();

    public DbSet<WaitlistEntry> WaitlistEntries => Set<WaitlistEntry>();

    public DbSet<UserWallet> UserWallets => Set<UserWallet>();

    public DbSet<PaymentSettlement> PaymentSettlements => Set<PaymentSettlement>();

    public DbSet<DriverLedgerEntry> DriverLedgerEntries => Set<DriverLedgerEntry>();

    public DbSet<DispatchTask> DispatchTasks => Set<DispatchTask>();

    public DbSet<Homestay> Homestays => Set<Homestay>();

    public DbSet<RoomAvailability> RoomAvailabilities => Set<RoomAvailability>();

    public DbSet<SupportTicket> SupportTickets => Set<SupportTicket>();

    public DbSet<TicketMessage> TicketMessages => Set<TicketMessage>();

    public DbSet<AdminActionLog> AdminActionLogs => Set<AdminActionLog>();

    public DbSet<AppEventLog> AppEventLogs => Set<AppEventLog>();

    public DbSet<RideEvent> RideEvents => Set<RideEvent>();

    public DbSet<EmergencyContact> EmergencyContacts => Set<EmergencyContact>();

    public DbSet<SosAlert> SosAlerts => Set<SosAlert>();

    public DbSet<SavedLocation> SavedLocations => Set<SavedLocation>();

    public DbSet<ScheduledRide> ScheduledRides => Set<ScheduledRide>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(ApplicationDbContext).Assembly);

        if (Database.ProviderName == "Npgsql.EntityFrameworkCore.PostgreSQL")
        {
            modelBuilder.HasPostgresExtension("postgis");
        }

        base.OnModelCreating(modelBuilder);
    }

    public override Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        foreach (var entry in ChangeTracker.Entries<Domain.Common.BaseEntity>())
        {
            if (entry.State == EntityState.Modified)
                entry.Entity.MarkUpdated();
        }

        return base.SaveChangesAsync(cancellationToken);
    }

    public bool IsTransactionSupported
        => Database.ProviderName is "Npgsql.EntityFrameworkCore.PostgreSQL"
            or "Microsoft.EntityFrameworkCore.Sqlite";

    public bool IsPostgreSQL
        => Database.ProviderName == "Npgsql.EntityFrameworkCore.PostgreSQL";

    public async Task<IDbContextTransaction?> BeginTransactionAsync(CancellationToken cancellationToken = default)
    {
        // The in-memory provider cannot participate in explicit transactions;
        // callers treat a null result as "transaction not required".
        if (!IsTransactionSupported)
            return null;

        return await Database.BeginTransactionAsync(
            IsolationLevel.Serializable,
            cancellationToken);
    }
}