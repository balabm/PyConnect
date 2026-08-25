using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddPartyEcosystem : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "equipment_items",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DailyRentalPrice = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    SecurityDepositAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    TotalUnits = table.Column<int>(type: "integer", nullable: false),
                    AvailableUnits = table.Column<int>(type: "integer", nullable: false),
                    Category = table.Column<string>(type: "character varying(30)", maxLength: 30, nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    IsAvailable = table.Column<bool>(type: "boolean", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_equipment_items", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "equipment_rentals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    EquipmentItemId = table.Column<Guid>(type: "uuid", nullable: false),
                    UnitsBooked = table.Column<int>(type: "integer", nullable: false),
                    RentalStart = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    RentalEnd = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    DailyRate = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    SecurityDeposit = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    DepositPaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    DepositPenalty = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    DepositRefunded = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    ConditionPhotosJson = table.Column<string>(type: "jsonb", nullable: true),
                    ReturnConditionPhotosJson = table.Column<string>(type: "jsonb", nullable: true),
                    ActualReturnAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    DeliveryAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Notes = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_equipment_rentals", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "p2p_event_tickets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    P2pEventId = table.Column<Guid>(type: "uuid", nullable: false),
                    BuyerUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    PricePaid = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    PlatformFee = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    HostPayout = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    PaymentStatus = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    PaymentReference = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    PassToken = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CheckedInAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    PurchasedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_p2p_event_tickets", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "p2p_events",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    HostUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Title = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Slug = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Description = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    WhatsOffered = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    StartsAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    EndsAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    location_lat = table.Column<double>(type: "double precision", nullable: false),
                    location_lng = table.Column<double>(type: "double precision", nullable: false),
                    Address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    EntryPrice = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    CapacityLimit = table.Column<int>(type: "integer", nullable: false),
                    TicketsSold = table.Column<int>(type: "integer", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    ImageUrl = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    PlatformFeePercent = table.Column<decimal>(type: "numeric(5,2)", precision: 5, scale: 2, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_p2p_events", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_equipment_items_IsAvailable",
                table: "equipment_items",
                column: "IsAvailable");

            migrationBuilder.CreateIndex(
                name: "IX_equipment_items_VendorId",
                table: "equipment_items",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_equipment_rentals_Status",
                table: "equipment_rentals",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_equipment_rentals_UserId",
                table: "equipment_rentals",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_equipment_rentals_VendorId",
                table: "equipment_rentals",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_equipment_rentals_VendorId_Status",
                table: "equipment_rentals",
                columns: new[] { "VendorId", "Status" });

            migrationBuilder.CreateIndex(
                name: "IX_p2p_event_tickets_P2pEventId",
                table: "p2p_event_tickets",
                column: "P2pEventId");

            migrationBuilder.CreateIndex(
                name: "IX_p2p_event_tickets_P2pEventId_BuyerUserId",
                table: "p2p_event_tickets",
                columns: new[] { "P2pEventId", "BuyerUserId" });

            migrationBuilder.CreateIndex(
                name: "IX_p2p_event_tickets_PassToken",
                table: "p2p_event_tickets",
                column: "PassToken",
                unique: true,
                filter: "\"PassToken\" IS NOT NULL");

            migrationBuilder.CreateIndex(
                name: "IX_p2p_events_HostUserId",
                table: "p2p_events",
                column: "HostUserId");

            migrationBuilder.CreateIndex(
                name: "IX_p2p_events_Slug",
                table: "p2p_events",
                column: "Slug",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_p2p_events_Status",
                table: "p2p_events",
                column: "Status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "equipment_items");

            migrationBuilder.DropTable(
                name: "equipment_rentals");

            migrationBuilder.DropTable(
                name: "p2p_event_tickets");

            migrationBuilder.DropTable(
                name: "p2p_events");
        }
    }
}
