using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDineInSubscriptionsAndTrustScore : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsCodDisabled",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<bool>(
                name: "IsShadowBanned",
                table: "users",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "TrustScore",
                table: "users",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "TrustScoreUpdatedAt",
                table: "users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "OrderType",
                table: "food_orders",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "TableId",
                table: "food_orders",
                type: "integer",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "dine_in_sessions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    VenueId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: false),
                    TableId = table.Column<int>(type: "integer", nullable: false),
                    OpenedByUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    RootOrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    OpenedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    ClosedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    TotalSettled = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_dine_in_sessions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_dine_in_sessions_OpenedByUserId",
                table: "dine_in_sessions",
                column: "OpenedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_dine_in_sessions_VenueId_TableId_Status",
                table: "dine_in_sessions",
                columns: new[] { "VenueId", "TableId", "Status" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "dine_in_sessions");

            migrationBuilder.DropColumn(
                name: "IsCodDisabled",
                table: "users");

            migrationBuilder.DropColumn(
                name: "IsShadowBanned",
                table: "users");

            migrationBuilder.DropColumn(
                name: "TrustScore",
                table: "users");

            migrationBuilder.DropColumn(
                name: "TrustScoreUpdatedAt",
                table: "users");

            migrationBuilder.DropColumn(
                name: "OrderType",
                table: "food_orders");

            migrationBuilder.DropColumn(
                name: "TableId",
                table: "food_orders");
        }
    }
}
