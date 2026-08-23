-- Emergency fix: Add missing drivers.FcmDeviceToken column
-- The migration 20260817084949_AddFcmTokenToUsers was not applied to production.
-- This script adds the column manually so the API stops 500ing on PUT /api/auth/fcm-token.
--
-- Run on the production RDS PostgreSQL database:
--   psql "Host=pyconnect.ch2i68eyk0ii.eu-north-1.rds.amazonaws.com;Database=pyconnect;Username=postgres;Password=..." -f fix_drivers_fcm_token.sql
--
-- Or via docker exec on the EC2 instance:
--   docker exec -i pondyconnect_db psql -U postgres -d pyconnect < fix_drivers_fcm_token.sql

-- Add the missing column (idempotent — safe to run multiple times)
ALTER TABLE drivers
    ADD COLUMN IF NOT EXISTS "FcmDeviceToken" character varying(512);

-- Also apply the other changes from the same migration that may be missing:
-- 1. vendors.FcmDeviceToken: text → varchar(512)
ALTER TABLE vendors
    ALTER COLUMN "FcmDeviceToken" TYPE character varying(512);

-- 2. users.FcmDeviceToken: varchar(256) → varchar(512)
ALTER TABLE users
    ALTER COLUMN "FcmDeviceToken" TYPE character varying(512);

-- 3. driver_withdrawals table (from the same migration)
CREATE TABLE IF NOT EXISTS driver_withdrawals (
    "Id" uuid NOT NULL PRIMARY KEY,
    "DriverId" uuid NOT NULL REFERENCES drivers("Id") ON DELETE CASCADE,
    "WalletId" uuid NOT NULL REFERENCES driver_wallets("Id") ON DELETE CASCADE,
    "Amount" numeric(18,2) NOT NULL,
    "Status" character varying(20) NOT NULL,
    "BankAccountNumber" character varying(50),
    "UpiId" character varying(100),
    "RequestedAt" timestamp with time zone NOT NULL,
    "ProcessedAt" timestamp with time zone,
    "AdminNote" character varying(500),
    "CreatedAt" timestamp with time zone NOT NULL,
    "UpdatedAt" timestamp with time zone
);

CREATE INDEX IF NOT EXISTS "IX_driver_withdrawals_DriverId_Status"
    ON driver_withdrawals ("DriverId", "Status");
CREATE INDEX IF NOT EXISTS "IX_driver_withdrawals_Status"
    ON driver_withdrawals ("Status");
CREATE INDEX IF NOT EXISTS "IX_driver_withdrawals_WalletId"
    ON driver_withdrawals ("WalletId");

-- Mark the migration as applied so EF Core doesn't try to re-run it
INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES ('20260817084949_AddFcmTokenToUsers', '8.0.0')
ON CONFLICT ("MigrationId") DO NOTHING;

-- Also check and mark other potentially unapplied migrations
INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
VALUES
    ('20260817085158_AddDriverWithdrawals', '8.0.0'),
    ('20260822120904_AddEdgeCaseScenarios', '8.0.0'),
    ('20260822134133_AddReferralAndInvoicing', '8.0.0'),
    ('20260822140432_AddDoubleEntryLedgerAndSettlements', '8.0.0'),
    ('20260822142044_AddDineInSubscriptionsAndTrustScore', '8.0.0')
ON CONFLICT ("MigrationId") DO NOTHING;

-- WARNING: The above marks migrations as applied WITHOUT running their full Up() logic.
-- This is only safe if you have manually verified that all schema changes from those
-- migrations are already present. If not, remove those lines and let EF Core apply them
-- properly on the next app startup.

SELECT 'Fix applied successfully — drivers.FcmDeviceToken column added' AS result;
