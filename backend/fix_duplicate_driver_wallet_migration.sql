-- Emergency fix: mark the duplicate AddDriverWallet migration as applied.
--
-- The 20260816081016_AddDriverWallet migration was generated with a broken
-- snapshot that duplicated CreateTable calls from earlier migrations
-- (AddMenuModifiers and AddConsumerFlags). Running it caused:
--   42P07: relation "consumer_flags" already exists
--
-- The migration has been converted to a no-op in code. If the container
-- still can't start (e.g. __EFMigrationsHistory is inconsistent), run this
-- script directly against the production RDS PostgreSQL instance to mark
-- the migration as already applied, then restart the container.
--
-- Usage:
--   PGPASSWORD=<password> psql -h pyconnect.ch2i68eyk0ii.eu-north-1.rds.amazonaws.com \
--     -U postgres -d pondyconnect -f fix_duplicate_driver_wallet_migration.sql

-- Insert the migration record if it doesn't already exist.
INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
SELECT '20260816081016_AddDriverWallet', '8.0.11'
WHERE NOT EXISTS (
    SELECT 1 FROM "__EFMigrationsHistory"
    WHERE "MigrationId" = '20260816081016_AddDriverWallet'
);

-- Verify the current migration state.
SELECT "MigrationId" FROM "__EFMigrationsHistory" ORDER BY "MigrationId";
