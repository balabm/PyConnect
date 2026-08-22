using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDoubleEntryLedgerAndSettlements : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "FundAccountId",
                table: "vendors",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "IsBankVerified",
                table: "vendors",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<decimal>(
                name: "WalletBalance",
                table: "vendors",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.CreateTable(
                name: "ChargebackDisputes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    PaymentId = table.Column<Guid>(type: "uuid", nullable: false),
                    UserId = table.Column<Guid>(type: "uuid", nullable: false),
                    OrderId = table.Column<Guid>(type: "uuid", nullable: true),
                    OrderType = table.Column<string>(type: "text", nullable: true),
                    ChargebackAmount = table.Column<decimal>(type: "numeric", nullable: false),
                    ProviderDisputeId = table.Column<string>(type: "text", nullable: true),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    EvidenceUrlsJson = table.Column<string>(type: "text", nullable: true),
                    EvidenceSummary = table.Column<string>(type: "text", nullable: true),
                    AccountFrozen = table.Column<bool>(type: "boolean", nullable: false),
                    ResolvedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    ResolutionNote = table.Column<string>(type: "text", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ChargebackDisputes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "ledger_entries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    TransactionId = table.Column<Guid>(type: "uuid", nullable: false),
                    Account = table.Column<int>(type: "integer", nullable: false),
                    IsDebit = table.Column<bool>(type: "boolean", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    ReferenceType = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: false),
                    ReferenceId = table.Column<Guid>(type: "uuid", nullable: false),
                    VendorId = table.Column<Guid>(type: "uuid", nullable: true),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: true),
                    Description = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ledger_entries", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "payout_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    RecipientType = table.Column<int>(type: "integer", nullable: false),
                    RecipientId = table.Column<Guid>(type: "uuid", nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    TdsDeducted = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    NetAmount = table.Column<decimal>(type: "numeric(14,2)", nullable: false),
                    Status = table.Column<int>(type: "integer", nullable: false),
                    DestinationAccount = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    DestinationIfsc = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    DestinationUpi = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    ProviderPayoutId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: true),
                    UtrNumber = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    FailureReason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    LedgerTransactionId = table.Column<Guid>(type: "uuid", nullable: true),
                    SettlementIds = table.Column<string>(type: "character varying(2000)", maxLength: 2000, nullable: true),
                    ProcessedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    FailedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_payout_requests", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_ledger_entries_Account_ReferenceType",
                table: "ledger_entries",
                columns: new[] { "Account", "ReferenceType" });

            migrationBuilder.CreateIndex(
                name: "IX_ledger_entries_DriverId",
                table: "ledger_entries",
                column: "DriverId");

            migrationBuilder.CreateIndex(
                name: "IX_ledger_entries_TransactionId",
                table: "ledger_entries",
                column: "TransactionId");

            migrationBuilder.CreateIndex(
                name: "IX_ledger_entries_VendorId",
                table: "ledger_entries",
                column: "VendorId");

            migrationBuilder.CreateIndex(
                name: "IX_payout_requests_ProviderPayoutId",
                table: "payout_requests",
                column: "ProviderPayoutId");

            migrationBuilder.CreateIndex(
                name: "IX_payout_requests_RecipientId",
                table: "payout_requests",
                column: "RecipientId");

            migrationBuilder.CreateIndex(
                name: "IX_payout_requests_Status",
                table: "payout_requests",
                column: "Status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ChargebackDisputes");

            migrationBuilder.DropTable(
                name: "ledger_entries");

            migrationBuilder.DropTable(
                name: "payout_requests");

            migrationBuilder.DropColumn(
                name: "FundAccountId",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "IsBankVerified",
                table: "vendors");

            migrationBuilder.DropColumn(
                name: "WalletBalance",
                table: "vendors");
        }
    }
}
