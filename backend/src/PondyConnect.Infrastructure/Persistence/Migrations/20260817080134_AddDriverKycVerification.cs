using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDriverKycVerification : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "KycAutoApproved",
                table: "drivers",
                type: "boolean",
                nullable: true);

            migrationBuilder.AddColumn<double>(
                name: "KycConfidence",
                table: "drivers",
                type: "double precision",
                precision: 3,
                scale: 2,
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "KycExpiryDate",
                table: "drivers",
                type: "timestamptz",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "KycLicenseNumber",
                table: "drivers",
                type: "character varying(50)",
                maxLength: 50,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "KycParsedName",
                table: "drivers",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "KycVerificationReason",
                table: "drivers",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "BatchGroupId",
                table: "dispatch_tasks",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "dispute_tickets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    OrderType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    Category = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    Subject = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Description = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    PhotoUrl = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    Status = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    ResolutionAmount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: true),
                    ResolutionNote = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: true),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_dispute_tickets", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_dispute_tickets_OrderId",
                table: "dispute_tickets",
                column: "OrderId");

            migrationBuilder.CreateIndex(
                name: "IX_dispute_tickets_UserId",
                table: "dispute_tickets",
                column: "UserId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "dispute_tickets");

            migrationBuilder.DropColumn(
                name: "KycAutoApproved",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "KycConfidence",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "KycExpiryDate",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "KycLicenseNumber",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "KycParsedName",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "KycVerificationReason",
                table: "drivers");

            migrationBuilder.DropColumn(
                name: "BatchGroupId",
                table: "dispatch_tasks");
        }
    }
}
