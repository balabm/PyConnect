using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddGenieAndSplitPayments : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "genie_errands",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    Description = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    PickupAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    PickupLat = table.Column<double>(type: "double precision", nullable: true),
                    PickupLng = table.Column<double>(type: "double precision", nullable: true),
                    DropoffAddress = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    DropoffLat = table.Column<double>(type: "double precision", nullable: true),
                    DropoffLng = table.Column<double>(type: "double precision", nullable: true),
                    EstimatedCost = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    AuthHoldAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    CaptainId = table.Column<Guid>(type: "uuid", nullable: true),
                    ActualCost = table.Column<decimal>(type: "numeric(12,2)", nullable: true),
                    RazorpayOrderId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    RazorpayPaymentId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_genie_errands", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "split_payment_contributors",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PoolId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    ShareAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    PaidAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PaidAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_split_payment_contributors", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "split_payment_pools",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    CreatorUserId = table.Column<Guid>(type: "uuid", nullable: false),
                    TotalAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    CollectedAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    ReferenceType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    ReferenceId = table.Column<Guid>(type: "uuid", nullable: true),
                    DeepLinkSlug = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    Status = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    PerShareAmount = table.Column<decimal>(type: "numeric(12,2)", nullable: false),
                    MaxShares = table.Column<int>(type: "integer", nullable: false),
                    ClaimedShares = table.Column<int>(type: "integer", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_split_payment_pools", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_genie_errands_CaptainId",
                table: "genie_errands",
                column: "CaptainId");

            migrationBuilder.CreateIndex(
                name: "IX_genie_errands_Status",
                table: "genie_errands",
                column: "Status");

            migrationBuilder.CreateIndex(
                name: "IX_genie_errands_UserId",
                table: "genie_errands",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_contributors_PoolId",
                table: "split_payment_contributors",
                column: "PoolId");

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_contributors_PoolId_UserId",
                table: "split_payment_contributors",
                columns: new[] { "PoolId", "UserId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_contributors_UserId",
                table: "split_payment_contributors",
                column: "UserId");

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_pools_CreatorUserId",
                table: "split_payment_pools",
                column: "CreatorUserId");

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_pools_DeepLinkSlug",
                table: "split_payment_pools",
                column: "DeepLinkSlug",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_split_payment_pools_Status",
                table: "split_payment_pools",
                column: "Status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "genie_errands");

            migrationBuilder.DropTable(
                name: "split_payment_contributors");

            migrationBuilder.DropTable(
                name: "split_payment_pools");
        }
    }
}
