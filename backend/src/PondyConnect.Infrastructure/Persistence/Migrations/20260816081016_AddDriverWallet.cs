using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddDriverWallet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "consumer_flags",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ConsumerId = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    FlagType = table.Column<int>(type: "integer", nullable: false),
                    Reason = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    ShadowBanned = table.Column<bool>(type: "boolean", nullable: false),
                    CodRestricted = table.Column<bool>(type: "boolean", nullable: false),
                    ExpiresAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_consumer_flags", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "driver_wallets",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    DriverId = table.Column<Guid>(type: "uuid", nullable: false),
                    Balance = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: 0m),
                    HardLimit = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false, defaultValue: -1000.00m),
                    Currency = table.Column<string>(type: "character varying(3)", maxLength: 3, nullable: false, defaultValue: "INR"),
                    Suspended = table.Column<bool>(type: "boolean", nullable: false, defaultValue: false),
                    LastSettledAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_driver_wallets", x => x.Id);
                    table.ForeignKey(
                        name: "FK_driver_wallets_drivers_DriverId",
                        column: x => x.DriverId,
                        principalTable: "drivers",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "modifier_groups",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    MenuItemId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(100)", maxLength: 100, nullable: false),
                    MinSelections = table.Column<int>(type: "integer", nullable: false),
                    MaxSelections = table.Column<int>(type: "integer", nullable: false),
                    SortOrder = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_modifier_groups", x => x.Id);
                    table.ForeignKey(
                        name: "FK_modifier_groups_menu_items_MenuItemId",
                        column: x => x.MenuItemId,
                        principalTable: "menu_items",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "driver_wallet_transactions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    WalletId = table.Column<Guid>(type: "uuid", nullable: false),
                    Type = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: false),
                    Amount = table.Column<decimal>(type: "numeric(18,2)", precision: 18, scale: 2, nullable: false),
                    Description = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    ReferenceId = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: true),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamptz", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_driver_wallet_transactions", x => x.Id);
                    table.ForeignKey(
                        name: "FK_driver_wallet_transactions_driver_wallets_WalletId",
                        column: x => x.WalletId,
                        principalTable: "driver_wallets",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "modifiers",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ModifierGroupId = table.Column<Guid>(type: "uuid", nullable: false),
                    Name = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Price = table.Column<decimal>(type: "numeric(10,2)", precision: 10, scale: 2, nullable: false, defaultValue: 0m),
                    IsAvailable = table.Column<bool>(type: "boolean", nullable: false, defaultValue: true),
                    SortOrder = table.Column<int>(type: "integer", nullable: false, defaultValue: 0),
                    CreatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    UpdatedAt = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_modifiers", x => x.Id);
                    table.ForeignKey(
                        name: "FK_modifiers_modifier_groups_ModifierGroupId",
                        column: x => x.ModifierGroupId,
                        principalTable: "modifier_groups",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateIndex(
                name: "IX_consumer_flags_ConsumerId",
                table: "consumer_flags",
                column: "ConsumerId");

            migrationBuilder.CreateIndex(
                name: "IX_consumer_flags_ExpiresAt",
                table: "consumer_flags",
                column: "ExpiresAt");

            migrationBuilder.CreateIndex(
                name: "IX_driver_wallet_transactions_WalletId_CreatedAt",
                table: "driver_wallet_transactions",
                columns: new[] { "WalletId", "CreatedAt" });

            migrationBuilder.CreateIndex(
                name: "IX_driver_wallets_DriverId",
                table: "driver_wallets",
                column: "DriverId",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_modifier_groups_MenuItemId",
                table: "modifier_groups",
                column: "MenuItemId");

            migrationBuilder.CreateIndex(
                name: "IX_modifiers_ModifierGroupId",
                table: "modifiers",
                column: "ModifierGroupId");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "consumer_flags");

            migrationBuilder.DropTable(
                name: "driver_wallet_transactions");

            migrationBuilder.DropTable(
                name: "modifiers");

            migrationBuilder.DropTable(
                name: "driver_wallets");

            migrationBuilder.DropTable(
                name: "modifier_groups");
        }
    }
}
