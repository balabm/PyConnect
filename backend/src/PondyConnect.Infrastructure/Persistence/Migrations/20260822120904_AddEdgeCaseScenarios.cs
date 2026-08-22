using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddEdgeCaseScenarios : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "DynamicPrepBufferMinutes",
                table: "vendors",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<bool>(
                name: "IsBusyMode",
                table: "vendors",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "PyCoins",
                table: "user_wallets",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ActualReturnAt",
                table: "scooter_rentals",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "ConditionPhotosAt",
                table: "scooter_rentals",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ConditionPhotosJson",
                table: "scooter_rentals",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DepositPaymentReference",
                table: "scooter_rentals",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "DepositPenalty",
                table: "scooter_rentals",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<decimal>(
                name: "DepositRefunded",
                table: "scooter_rentals",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "ReturnConditionPhotosJson",
                table: "scooter_rentals",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "SecurityDeposit",
                table: "scooter_rentals",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "PendingLockUntil",
                table: "room_availability",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "PendingLockedByUserId",
                table: "room_availability",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsFareLocked",
                table: "ride_requests",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<Guid>(
                name: "OriginalRideId",
                table: "ride_requests",
                type: "uuid",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "TollAndParking",
                table: "ride_requests",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<string>(
                name: "TollReceiptUrl",
                table: "ride_requests",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "IntakeImageUrl",
                table: "luggage_drop_offs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "RetrievalPin",
                table: "luggage_drop_offs",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "RetrievalPinGeneratedAt",
                table: "luggage_drop_offs",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "DeliveryProofUrl",
                table: "food_orders",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsSealedBagConfirmed",
                table: "food_orders",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "SealedBagConfirmedAt",
                table: "food_orders",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<decimal>(
                name: "Taxes",
                table: "food_orders",
                type: "numeric(10,2)",
                precision: 10,
                scale: 2,
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "GuestKycs",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    BookingId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    IdFrontUrl = table.Column<string>(type: "text", nullable: true),
                    IdBackUrl = table.Column<string>(type: "text", nullable: true),
                    IdType = table.Column<string>(type: "text", nullable: true),
                    IsUploaded = table.Column<bool>(type: "boolean", nullable: false),
                    UploadedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    IsViewedByPartner = table.Column<bool>(type: "boolean", nullable: false),
                    ViewedByPartnerAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_GuestKycs", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "user_addresses",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    DoorFlat = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Landmark = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    Tag = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    FormattedAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    latitude = table.Column<double>(type: "double precision", nullable: false),
                    longitude = table.Column<double>(type: "double precision", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_addresses", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_user_addresses_UserId",
                table: "user_addresses",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "GuestKycs");

            migrationBuilder.DropTable(
                name: "user_addresses");

            migrationBuilder.DropColumn(
                name: "DynamicPrepBufferMinutes",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "IsBusyMode",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "PyCoins",
                table: "user_wallets");

            migrationBuilder.DropColumn(
                name: "ActualReturnAt",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "ConditionPhotosAt",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "ConditionPhotosJson",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "DepositPaymentReference",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "DepositPenalty",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "DepositRefunded",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "ReturnConditionPhotosJson",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "SecurityDeposit",
                table: "scooter_rentals");

            migrationBuilder.DropColumn(
                name: "PendingLockUntil",
                table: "room_availability");

            migrationBuilder.DropColumn(
                name: "PendingLockedByUserId",
                table: "room_availability");

            migrationBuilder.DropColumn(
                name: "IsFareLocked",
                table: "ride_requests");

            migrationBuilder.DropColumn(
                name: "OriginalRideId",
                table: "ride_requests");

            migrationBuilder.DropColumn(
                name: "TollAndParking",
                table: "ride_requests");

            migrationBuilder.DropColumn(
                name: "TollReceiptUrl",
                table: "ride_requests");

            migrationBuilder.DropColumn(
                name: "IntakeImageUrl",
                table: "luggage_drop_offs");

            migrationBuilder.DropColumn(
                name: "RetrievalPin",
                table: "luggage_drop_offs");

            migrationBuilder.DropColumn(
                name: "RetrievalPinGeneratedAt",
                table: "luggage_drop_offs");

            migrationBuilder.DropColumn(
                name: "DeliveryProofUrl",
                table: "food_orders");

            migrationBuilder.DropColumn(
                name: "IsSealedBagConfirmed",
                table: "food_orders");

            migrationBuilder.DropColumn(
                name: "SealedBagConfirmedAt",
                table: "food_orders");

            migrationBuilder.DropColumn(
                name: "Taxes",
                table: "food_orders");
        }
    }
}
