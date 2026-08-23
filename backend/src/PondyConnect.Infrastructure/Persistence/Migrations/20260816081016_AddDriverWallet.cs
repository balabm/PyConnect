using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace PondyConnect.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    /// <remarks>
    /// This migration was originally generated with a broken model snapshot
    /// that included tables already created by earlier migrations:
    ///   - consumer_flags (created by 20260816080456_AddConsumerFlags)
    ///   - driver_wallets (created by 20260816080320_AddMenuModifiers)
    ///   - driver_wallet_transactions (created by 20260816080320_AddMenuModifiers)
    ///   - modifier_groups (created by 20260816080320_AddMenuModifiers)
    ///   - modifiers (created by 20260816080320_AddMenuModifiers)
    ///
    /// Running the original Up() caused "relation already exists" errors
    /// (42P07) on production because those tables were already present.
    /// The Up/Down methods are now no-ops so EF records the migration as
    /// applied without attempting duplicate DDL.
    /// </remarks>
    public partial class AddDriverWallet : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // No-op: all tables were created by earlier migrations.
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // No-op: tables are owned by earlier migrations.
        }
    }
}
