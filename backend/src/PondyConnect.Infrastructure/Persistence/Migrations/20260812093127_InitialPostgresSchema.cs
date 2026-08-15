using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class InitialPostgresSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterDatabase()
                .Annotation("Npgsql:PostgresExtension:postgis", ",,");

            migrationBuilder.CreateTable(
                name: "app_event_logs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: true),
                    SessionId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    EventName = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    EventPayload = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_app_event_logs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "bundle_bookings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    TotalPrice = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    DiscountedPrice = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    PassToken = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    PassType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_bundle_bookings", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "dispatch_tasks",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TaskType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    SourceEntityId = table.Column<Guid>(type: "uuid", nullable: true),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    pickup_lat = table.Column<double>(type: "double precision", nullable: false),
                    pickup_lng = table.Column<double>(type: "double precision", nullable: false),
                    dropoff_lat = table.Column<double>(type: "double precision", nullable: false),
                    dropoff_lng = table.Column<double>(type: "double precision", nullable: false),
                    PickupAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    DropoffAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    DriverEarnings = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Available"),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_dispatch_tasks", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "driver_ledger_entries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    TransactionType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Reference = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_driver_ledger_entries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "drivers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    VehicleType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    VehiclePlate = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    IsOnline = table.Column<bool>(type: "boolean", nullable: false),
                    IsApproved = table.Column<bool>(type: "boolean", nullable: false),
                    location_lat = table.Column<double>(type: "double precision", nullable: false),
                    location_lng = table.Column<double>(type: "double precision", nullable: false),
                    Rating = table.Column<double>(type: "double precision", precision: 3, scale: 2, nullable: false),
                    TotalRides = table.Column<int>(type: "integer", nullable: false),
                    TotalRatings = table.Column<int>(type: "integer", nullable: false),
                    AcceptanceRate = table.Column<double>(type: "double precision", precision: 5, scale: 4, nullable: false, defaultValue: 1.0),
                    TotalOffers = table.Column<int>(type: "integer", nullable: false),
                    TotalAccepted = table.Column<int>(type: "integer", nullable: false),
                    CancellationRate = table.Column<double>(type: "double precision", precision: 5, scale: 4, nullable: false, defaultValue: 0.0),
                    TotalCancellations = table.Column<int>(type: "integer", nullable: false),
                    IsOnRide = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    CurrentRideId = table.Column<Guid>(type: "uuid", nullable: true),
                    LastLocationAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    AadhaarUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DrivingLicenseUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    RcUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    UpiId = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    IsKycUploaded = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    EmergencyContactName = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    EmergencyContactPhone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_drivers", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "emergency_contacts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    Relationship = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_emergency_contacts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "food_orders",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    SubTotal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    VendorPayout = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    DeliveryFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    LateNightDriverBonus = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    PlatformFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    PlacedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    DeliveredAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    DeliveryAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    delivery_lat = table.Column<double>(type: "double precision", nullable: false),
                    delivery_lng = table.Column<double>(type: "double precision", nullable: false),
                    PaymentMethod = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_food_orders", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "homestays",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HostId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: false),
                    LocationArea = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    Latitude = table.Column<double>(type: "double precision", nullable: false),
                    Longitude = table.Column<double>(type: "double precision", nullable: false),
                    NightlyRate = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    MaxGuests = table.Column<int>(type: "integer", nullable: false),
                    HasWifi = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    IsVerified = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_homestays", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "menu_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<Guid>(type: "uuid", nullable: true),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    IsAvailable = table.Column<bool>(type: "boolean", nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    IsLateNight = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_menu_items", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "payments",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ServiceBookingId = table.Column<Guid>(type: "uuid", nullable: true),
                    TransitTripId = table.Column<Guid>(type: "uuid", nullable: true),
                    LuggageDropOffId = table.Column<Guid>(type: "uuid", nullable: true),
                    ScooterRentalId = table.Column<Guid>(type: "uuid", nullable: true),
                    FoodOrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    Amount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    Provider = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Method = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ProviderOrderId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ProviderPaymentId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    FailureReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CapturedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    RefundedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_payments", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "product_orders",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    SubTotal = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    DeliveryFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false),
                    DeliveryAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    delivery_lat = table.Column<double>(type: "double precision", nullable: false),
                    delivery_lng = table.Column<double>(type: "double precision", nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PlacedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    DeliveredAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_product_orders", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "products",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    Category = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    SubCategory = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Brand = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    IsAvailable = table.Column<bool>(type: "boolean", nullable: false),
                    StockCount = table.Column<int>(type: "integer", nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    IsLateNightEssential = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_products", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ride_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RideId = table.Column<Guid>(type: "uuid", nullable: false),
                    EventType = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    Timestamp = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    ActorUserId = table.Column<Guid>(type: "uuid", nullable: true),
                    Metadata = table.Column<string>(type: "jsonb", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ride_events", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ride_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    pickup_lat = table.Column<double>(type: "double precision", nullable: false),
                    pickup_lng = table.Column<double>(type: "double precision", nullable: false),
                    PickupAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    dropoff_lat = table.Column<double>(type: "double precision", nullable: false),
                    dropoff_lng = table.Column<double>(type: "double precision", nullable: false),
                    DropoffAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    DistanceKm = table.Column<double>(type: "double precision", precision: 8, scale: 2, nullable: false),
                    EstimatedDurationMin = table.Column<int>(type: "integer", nullable: false),
                    ActualDistanceKm = table.Column<double>(type: "double precision", precision: 8, scale: 2, nullable: true),
                    ActualDurationMin = table.Column<int>(type: "integer", nullable: true),
                    VehicleType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Fare = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    PlatformBookingFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    PaymentMethod = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Status = table.Column<string>(type: "character varying(25)", maxLength: 25, nullable: false),
                    RequestedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    AcceptedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    DriverAssignedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    ArrivedAtPickupAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    StartedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CompletedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CancelledAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CancelReason = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    CancelledBy = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    CancellationFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    IsSos = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    SosDriverPayout = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    PlatformEmergencyFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    SurgeMultiplier = table.Column<decimal>(type: "numeric(3,2)", precision: 3, scale: 2, nullable: false, defaultValue: 1.0m),
                    SurgeReason = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    BaseFare = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    DistanceFare = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    TimeFare = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    OtpCode = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: true),
                    OtpVerifiedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    RatingByRider = table.Column<int>(type: "integer", nullable: true),
                    RatingByDriver = table.Column<int>(type: "integer", nullable: true),
                    RiderFeedback = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DriverFeedback = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    TripShareToken = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ride_requests", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "room_availability",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HomestayId = table.Column<Guid>(type: "uuid", nullable: false),
                    Date = table.Column<DateOnly>(type: "date", nullable: false),
                    IsBooked = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    LockedByBookingId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_room_availability", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "saved_locations",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Label = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Address = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    latitude = table.Column<double>(type: "double precision", nullable: false),
                    longitude = table.Column<double>(type: "double precision", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_saved_locations", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "scheduled_rides",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    pickup_lat = table.Column<double>(type: "double precision", nullable: false),
                    pickup_lng = table.Column<double>(type: "double precision", nullable: false),
                    PickupAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    dropoff_lat = table.Column<double>(type: "double precision", nullable: false),
                    dropoff_lng = table.Column<double>(type: "double precision", nullable: false),
                    DropoffAddress = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    DistanceKm = table.Column<double>(type: "double precision", precision: 8, scale: 2, nullable: false),
                    VehicleType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaymentMethod = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ScheduledAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ResultingRideId = table.Column<Guid>(type: "uuid", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    EstimatedFare = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_scheduled_rides", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "sos_alerts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RideId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TriggeredAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    ResolvedBy = table.Column<Guid>(type: "uuid", nullable: true),
                    location_lat = table.Column<double>(type: "double precision", nullable: false),
                    location_lng = table.Column<double>(type: "double precision", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Active"),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_sos_alerts", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "subscription_plans",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    PlanType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    DurationDays = table.Column<int>(type: "integer", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_subscription_plans", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "support_tickets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Priority = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Source = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Latitude = table.Column<double>(type: "double precision", nullable: true),
                    Longitude = table.Column<double>(type: "double precision", nullable: true),
                    IssueCategory = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    AcknowledgedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_support_tickets", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "transit_hubs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Address = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    Kind = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    location_lat = table.Column<double>(type: "double precision", nullable: false),
                    location_lng = table.Column<double>(type: "double precision", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_transit_hubs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "users",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Phone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    Role = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    IsProMember = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    ProMemberUntil = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    IsVerifiedLocal = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    AadhaarHash = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    VerifiedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    HasAcceptedLiabilityWaiver = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    WaiverAcceptedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    DrivingLicenseNumber = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    KycVerificationStatus = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Pending"),
                    LastLoginAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    FcmDeviceToken = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_users", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "vendors",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    ContactPhone = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: true),
                    MerchantReference = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Category = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "LuggageCloak"),
                    IsApproved = table.Column<bool>(type: "boolean", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    SaaSTier = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Free"),
                    SaaSPlanExpiry = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    MonthlyFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    CreditBalance = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    CuisineType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Rating = table.Column<double>(type: "double precision", nullable: true),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DeliveryFee = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: true),
                    PrepTimeMinutes = table.Column<int>(type: "integer", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vendors", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "waitlist_entries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PhoneNumber = table.Column<string>(type: "character varying(15)", maxLength: 15, nullable: false),
                    SourceQrCodeLocation = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    IsConverted = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    ConvertedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_waitlist_entries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "bundle_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BundleBookingId = table.Column<Guid>(type: "uuid", nullable: false),
                    ServiceName = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    ServiceReferenceId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    ExperienceCategory = table.Column<int>(type: "integer", nullable: true),
                    OriginalPrice = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    IsRedeemed = table.Column<bool>(type: "boolean", nullable: false),
                    RedeemedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_bundle_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_bundle_items_bundle_bookings_BundleBookingId",
                        column: x => x.BundleBookingId,
                        principalTable: "bundle_bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "food_order_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    FoodOrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Quantity = table.Column<int>(type: "integer", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    SpecialInstructions = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_food_order_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_food_order_items_food_orders_FoodOrderId",
                        column: x => x.FoodOrderId,
                        principalTable: "food_orders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "payment_settlements",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PaymentId = table.Column<Guid>(type: "uuid", nullable: false),
                    ServiceBookingId = table.Column<Guid>(type: "uuid", nullable: true),
                    FoodOrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    RideRequestId = table.Column<Guid>(type: "uuid", nullable: true),
                    ScooterRentalId = table.Column<Guid>(type: "uuid", nullable: true),
                    GrossAmount = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    VendorPayout = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    DriverPayout = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    PlatformFee = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    SettlementStatus = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false, defaultValue: "Pending"),
                    ProcessedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_payment_settlements", x => x.Id);
                    table.ForeignKey(
                        name: "FK_payment_settlements_payments_PaymentId",
                        column: x => x.PaymentId,
                        principalTable: "payments",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "product_order_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ProductOrderId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Quantity = table.Column<int>(type: "integer", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_product_order_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_product_order_items_product_orders_ProductOrderId",
                        column: x => x.ProductOrderId,
                        principalTable: "product_orders",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_subscriptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    SubscriptionPlanId = table.Column<Guid>(type: "uuid", nullable: false),
                    StartsAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_subscriptions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_user_subscriptions_subscription_plans_SubscriptionPlanId",
                        column: x => x.SubscriptionPlanId,
                        principalTable: "subscription_plans",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "ticket_messages",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TicketId = table.Column<Guid>(type: "uuid", nullable: false),
                    SenderRole = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    MessageText = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ticket_messages", x => x.Id);
                    table.ForeignKey(
                        name: "FK_ticket_messages_support_tickets_TicketId",
                        column: x => x.TicketId,
                        principalTable: "support_tickets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "user_wallets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PromoBalance = table.Column<decimal>(type: "numeric(14,2)", nullable: false, defaultValue: 0m),
                    RealBalance = table.Column<decimal>(type: "numeric(14,2)", nullable: false, defaultValue: 0m),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_wallets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_user_wallets_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "luggage_drop_offs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    ScheduledFor = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    DroppedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    PickedUpAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    BagCount = table.Column<int>(type: "integer", nullable: false),
                    RatePerHour = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Status = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_luggage_drop_offs", x => x.Id);
                    table.ForeignKey(
                        name: "FK_luggage_drop_offs_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "scooter_rentals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    VehicleName = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: false),
                    VehiclePlate = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    RentalStart = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    RentalEnd = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    RatePerHour = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Status = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_scooter_rentals", x => x.Id);
                    table.ForeignKey(
                        name: "FK_scooter_rentals_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "service_bookings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    ServiceType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    Currency = table.Column<string>(type: "character varying(4)", maxLength: 4, nullable: false, defaultValue: "INR"),
                    ScheduledFor = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    CompletedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    PaymentStatus = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CheckInDate = table.Column<DateOnly>(type: "date", nullable: true),
                    CheckOutDate = table.Column<DateOnly>(type: "date", nullable: true),
                    HomestayId = table.Column<Guid>(type: "uuid", nullable: true),
                    VenueId = table.Column<Guid>(type: "uuid", nullable: true),
                    SeatCount = table.Column<int>(type: "integer", nullable: false),
                    PassToken = table.Column<string>(type: "character varying(128)", maxLength: 128, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_service_bookings", x => x.Id);
                    table.ForeignKey(
                        name: "FK_service_bookings_users_UserId",
                        column: x => x.UserId,
                        principalTable: "users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_service_bookings_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "transit_trips",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    HubId = table.Column<Guid>(type: "uuid", nullable: false),
                    ArrivalFrom = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    ArrivalMode = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ArrivalAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    PartySize = table.Column<int>(type: "integer", nullable: false),
                    DropOffLocation = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Price = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    AssignedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    StartedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CompletedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_transit_trips", x => x.Id);
                    table.ForeignKey(
                        name: "FK_transit_trips_transit_hubs_HubId",
                        column: x => x.HubId,
                        principalTable: "transit_hubs",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_transit_trips_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "vendor_promotions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    PromoType = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Title = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    TargetLatitude = table.Column<double>(type: "double precision", precision: 9, scale: 6, nullable: true),
                    TargetLongitude = table.Column<double>(type: "double precision", precision: 9, scale: 6, nullable: true),
                    TargetRadiusKm = table.Column<double>(type: "double precision", precision: 6, scale: 2, nullable: true),
                    Cost = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false),
                    DiscountPercentage = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: true),
                    StartsAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_vendor_promotions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_vendor_promotions_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "venues",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(160)", maxLength: 160, nullable: false),
                    Description = table.Column<string>(type: "text", nullable: true),
                    Category = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    location_lat = table.Column<double>(type: "double precision", nullable: false),
                    location_lng = table.Column<double>(type: "double precision", nullable: false),
                    CurrentCapacity = table.Column<int>(type: "integer", nullable: false),
                    CheckedInCount = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    MaxCapacity = table.Column<int>(type: "integer", nullable: false),
                    Address = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: true),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    IsActive = table.Column<bool>(type: "boolean", nullable: false),
                    IsPriorityPingActive = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    PriorityPingExpiry = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    ImageUrl = table.Column<string>(type: "text", nullable: true),
                    Rating = table.Column<double>(type: "double precision", nullable: true),
                    ReviewCount = table.Column<int>(type: "integer", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_venues", x => x.Id);
                    table.ForeignKey(
                        name: "FK_venues_vendors_VendorId",
                        column: x => x.VendorId,
                        principalTable: "vendors",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.SetNull);
                });

            migrationBuilder.CreateTable(
                name: "booking_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ServiceBookingId = table.Column<Guid>(type: "uuid", nullable: false),
                    Description = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Quantity = table.Column<int>(type: "integer", nullable: false),
                    UnitPrice = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_booking_items", x => x.Id);
                    table.ForeignKey(
                        name: "FK_booking_items_service_bookings_ServiceBookingId",
                        column: x => x.ServiceBookingId,
                        principalTable: "service_bookings",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "venue_availability",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<Guid>(type: "uuid", nullable: false),
                    DayOfWeek = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    OpensAt = table.Column<TimeOnly>(type: "time", nullable: false),
                    ClosesAt = table.Column<TimeOnly>(type: "time", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_venue_availability", x => x.Id);
                    table.ForeignKey(
                        name: "FK_venue_availability_venues_VenueId",
                        column: x => x.VenueId,
                        principalTable: "venues",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_app_event_logs_CreatedAt",
                table: "app_event_logs",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_app_event_logs_EventName",
                table: "app_event_logs",
                column: "EventName");

            migrationBuilder.CreateIndex(
                name: "IX_booking_items_ServiceBookingId",
                table: "booking_items",
                column: "ServiceBookingId");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_bookings_ExpiresAt",
                table: "bundle_bookings",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_bookings_Status",
                table: "bundle_bookings",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_bookings_UserId",
                table: "bundle_bookings",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_items_BundleBookingId",
                table: "bundle_items",
                column: "BundleBookingId");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_items_IsRedeemed",
                table: "bundle_items",
                column: "IsRedeemed");

            migrationBuilder.CreateIndex(
                name: "IX_bundle_items_ServiceReferenceId",
                table: "bundle_items",
                column: "ServiceReferenceId");

            migrationBuilder.CreateIndex(
                name: "IX_dispatch_tasks_DriverId",
                table: "dispatch_tasks",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_dispatch_tasks_Status",
                table: "dispatch_tasks",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_dispatch_tasks_TaskType",
                table: "dispatch_tasks",
                column: "TaskType");

            migrationBuilder.CreateIndex(
                name: "IX_driver_ledger_entries_CreatedAt",
                table: "driver_ledger_entries",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_driver_ledger_entries_DriverId",
                table: "driver_ledger_entries",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_IsApproved",
                table: "drivers",
                column: "IsApproved");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_IsOnline",
                table: "drivers",
                column: "IsOnline");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_IsOnRide",
                table: "drivers",
                column: "IsOnRide");

            migrationBuilder.CreateIndex(
                name: "IX_drivers_UserId",
                table: "drivers",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_emergency_contacts_UserId",
                table: "emergency_contacts",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_food_order_items_FoodOrderId",
                table: "food_order_items",
                column: "FoodOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_food_orders_Status",
                table: "food_orders",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_food_orders_UserId",
                table: "food_orders",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_food_orders_VendorId",
                table: "food_orders",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_homestays_HostId",
                table: "homestays",
                column: "HostId");

            migrationBuilder.CreateIndex(
                name: "IX_luggage_drop_offs_Status",
                table: "luggage_drop_offs",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_luggage_drop_offs_UserId",
                table: "luggage_drop_offs",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_luggage_drop_offs_VendorId",
                table: "luggage_drop_offs",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_menu_items_IsLateNight",
                table: "menu_items",
                column: "IsLateNight");

            migrationBuilder.CreateIndex(
                name: "IX_menu_items_VendorId_IsAvailable",
                table: "menu_items",
                columns: new[] { "VendorId", "IsAvailable" });

            migrationBuilder.CreateIndex(
                name: "IX_payment_settlements_FoodOrderId",
                table: "payment_settlements",
                column: "FoodOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_payment_settlements_PaymentId",
                table: "payment_settlements",
                column: "PaymentId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_payment_settlements_RideRequestId",
                table: "payment_settlements",
                column: "RideRequestId");

            migrationBuilder.CreateIndex(
                name: "IX_payment_settlements_ScooterRentalId",
                table: "payment_settlements",
                column: "ScooterRentalId");

            migrationBuilder.CreateIndex(
                name: "IX_payment_settlements_ServiceBookingId",
                table: "payment_settlements",
                column: "ServiceBookingId");

            migrationBuilder.CreateIndex(
                name: "IX_payments_FoodOrderId",
                table: "payments",
                column: "FoodOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_payments_LuggageDropOffId",
                table: "payments",
                column: "LuggageDropOffId");

            migrationBuilder.CreateIndex(
                name: "IX_payments_ProviderOrderId",
                table: "payments",
                column: "ProviderOrderId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_payments_ScooterRentalId",
                table: "payments",
                column: "ScooterRentalId");

            migrationBuilder.CreateIndex(
                name: "IX_payments_ServiceBookingId",
                table: "payments",
                column: "ServiceBookingId");

            migrationBuilder.CreateIndex(
                name: "IX_payments_Status",
                table: "payments",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_payments_TransitTripId",
                table: "payments",
                column: "TransitTripId");

            migrationBuilder.CreateIndex(
                name: "IX_product_order_items_ProductOrderId",
                table: "product_order_items",
                column: "ProductOrderId");

            migrationBuilder.CreateIndex(
                name: "IX_product_orders_UserId",
                table: "product_orders",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_product_orders_VendorId",
                table: "product_orders",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_products_Category_IsAvailable",
                table: "products",
                columns: new[] { "Category", "IsAvailable" });

            migrationBuilder.CreateIndex(
                name: "IX_products_IsLateNightEssential",
                table: "products",
                column: "IsLateNightEssential");

            migrationBuilder.CreateIndex(
                name: "IX_products_VendorId",
                table: "products",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_ride_events_RideId",
                table: "ride_events",
                column: "RideId");

            migrationBuilder.CreateIndex(
                name: "IX_ride_events_Timestamp",
                table: "ride_events",
                column: "Timestamp");

            migrationBuilder.CreateIndex(
                name: "IX_ride_requests_DriverId",
                table: "ride_requests",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_ride_requests_Status",
                table: "ride_requests",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_ride_requests_TripShareToken",
                table: "ride_requests",
                column: "TripShareToken",
                unique: true,
                filter: "\"TripShareToken\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_ride_requests_UserId",
                table: "ride_requests",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_room_availability_HomestayId",
                table: "room_availability",
                column: "HomestayId");

            migrationBuilder.CreateIndex(
                name: "IX_room_availability_HomestayId_Date",
                table: "room_availability",
                columns: new[] { "HomestayId", "Date" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_saved_locations_UserId",
                table: "saved_locations",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_scheduled_rides_ScheduledAt",
                table: "scheduled_rides",
                column: "ScheduledAt");

            migrationBuilder.CreateIndex(
                name: "IX_scheduled_rides_Status",
                table: "scheduled_rides",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_scheduled_rides_UserId",
                table: "scheduled_rides",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_scooter_rentals_Status",
                table: "scooter_rentals",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_scooter_rentals_UserId",
                table: "scooter_rentals",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_scooter_rentals_VendorId",
                table: "scooter_rentals",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_HomestayId",
                table: "service_bookings",
                column: "HomestayId");

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_PassToken",
                table: "service_bookings",
                column: "PassToken",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_ScheduledFor_ServiceType",
                table: "service_bookings",
                columns: new[] { "ScheduledFor", "ServiceType" });

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_UserId",
                table: "service_bookings",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_VendorId",
                table: "service_bookings",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_service_bookings_VenueId",
                table: "service_bookings",
                column: "VenueId");

            migrationBuilder.CreateIndex(
                name: "IX_sos_alerts_RideId",
                table: "sos_alerts",
                column: "RideId");

            migrationBuilder.CreateIndex(
                name: "IX_sos_alerts_Status",
                table: "sos_alerts",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_subscription_plans_IsActive",
                table: "subscription_plans",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_subscription_plans_PlanType",
                table: "subscription_plans",
                column: "PlanType");

            migrationBuilder.CreateIndex(
                name: "IX_support_tickets_Priority",
                table: "support_tickets",
                column: "Priority");

            migrationBuilder.CreateIndex(
                name: "IX_support_tickets_Status",
                table: "support_tickets",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_support_tickets_UserId",
                table: "support_tickets",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_ticket_messages_TicketId",
                table: "ticket_messages",
                column: "TicketId");

            migrationBuilder.CreateIndex(
                name: "IX_transit_hubs_Kind",
                table: "transit_hubs",
                column: "Kind");

            migrationBuilder.CreateIndex(
                name: "IX_transit_trips_HubId",
                table: "transit_trips",
                column: "HubId");

            migrationBuilder.CreateIndex(
                name: "IX_transit_trips_Status",
                table: "transit_trips",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_transit_trips_UserId",
                table: "transit_trips",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_transit_trips_VendorId",
                table: "transit_trips",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_user_subscriptions_ExpiresAt",
                table: "user_subscriptions",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_user_subscriptions_IsActive",
                table: "user_subscriptions",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_user_subscriptions_SubscriptionPlanId",
                table: "user_subscriptions",
                column: "SubscriptionPlanId");

            migrationBuilder.CreateIndex(
                name: "IX_user_subscriptions_UserId",
                table: "user_subscriptions",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_user_subscriptions_UserId_IsActive",
                table: "user_subscriptions",
                columns: new[] { "UserId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_user_wallets_UserId",
                table: "user_wallets",
                column: "UserId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_users_Phone",
                table: "users",
                column: "Phone",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_vendor_promotions_ExpiresAt",
                table: "vendor_promotions",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_promotions_IsActive",
                table: "vendor_promotions",
                column: "IsActive");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_promotions_PromoType",
                table: "vendor_promotions",
                column: "PromoType");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_promotions_VendorId",
                table: "vendor_promotions",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_vendor_promotions_VendorId_IsActive",
                table: "vendor_promotions",
                columns: new[] { "VendorId", "IsActive" });

            migrationBuilder.CreateIndex(
                name: "IX_vendors_Category",
                table: "vendors",
                column: "Category");

            migrationBuilder.CreateIndex(
                name: "IX_vendors_IsApproved",
                table: "vendors",
                column: "IsApproved");

            migrationBuilder.CreateIndex(
                name: "IX_venue_availability_VenueId",
                table: "venue_availability",
                column: "VenueId");

            migrationBuilder.CreateIndex(
                name: "IX_venues_Category",
                table: "venues",
                column: "Category");

            migrationBuilder.CreateIndex(
                name: "IX_venues_IsPriorityPingActive",
                table: "venues",
                column: "IsPriorityPingActive");

            migrationBuilder.CreateIndex(
                name: "IX_venues_VendorId",
                table: "venues",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_waitlist_entries_PhoneNumber",
                table: "waitlist_entries",
                column: "PhoneNumber",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "app_event_logs");

            migrationBuilder.DropTable(
                name: "booking_items");

            migrationBuilder.DropTable(
                name: "bundle_items");

            migrationBuilder.DropTable(
                name: "dispatch_tasks");

            migrationBuilder.DropTable(
                name: "driver_ledger_entries");

            migrationBuilder.DropTable(
                name: "drivers");

            migrationBuilder.DropTable(
                name: "emergency_contacts");

            migrationBuilder.DropTable(
                name: "food_order_items");

            migrationBuilder.DropTable(
                name: "homestays");

            migrationBuilder.DropTable(
                name: "luggage_drop_offs");

            migrationBuilder.DropTable(
                name: "menu_items");

            migrationBuilder.DropTable(
                name: "payment_settlements");

            migrationBuilder.DropTable(
                name: "product_order_items");

            migrationBuilder.DropTable(
                name: "products");

            migrationBuilder.DropTable(
                name: "ride_events");

            migrationBuilder.DropTable(
                name: "ride_requests");

            migrationBuilder.DropTable(
                name: "room_availability");

            migrationBuilder.DropTable(
                name: "saved_locations");

            migrationBuilder.DropTable(
                name: "scheduled_rides");

            migrationBuilder.DropTable(
                name: "scooter_rentals");

            migrationBuilder.DropTable(
                name: "sos_alerts");

            migrationBuilder.DropTable(
                name: "ticket_messages");

            migrationBuilder.DropTable(
                name: "transit_trips");

            migrationBuilder.DropTable(
                name: "user_subscriptions");

            migrationBuilder.DropTable(
                name: "user_wallets");

            migrationBuilder.DropTable(
                name: "vendor_promotions");

            migrationBuilder.DropTable(
                name: "venue_availability");

            migrationBuilder.DropTable(
                name: "waitlist_entries");

            migrationBuilder.DropTable(
                name: "service_bookings");

            migrationBuilder.DropTable(
                name: "bundle_bookings");

            migrationBuilder.DropTable(
                name: "food_orders");

            migrationBuilder.DropTable(
                name: "payments");

            migrationBuilder.DropTable(
                name: "product_orders");

            migrationBuilder.DropTable(
                name: "support_tickets");

            migrationBuilder.DropTable(
                name: "transit_hubs");

            migrationBuilder.DropTable(
                name: "subscription_plans");

            migrationBuilder.DropTable(
                name: "venues");

            migrationBuilder.DropTable(
                name: "users");

            migrationBuilder.DropTable(
                name: "vendors");
        }
    }
}
