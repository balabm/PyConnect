#!/bin/bash
# PY Connect — Nightly PostgreSQL backup with GPG encryption
#
# Designed to run as a systemd timer. Produces a compressed, GPG-encrypted
# pg_dump snapshot and transfers it to cloud cold storage (S3).
#
# Configuration via environment variables or /etc/pyconnect/backup.env:
#   DB_HOST          — PostgreSQL host (default: localhost)
#   DB_PORT          — PostgreSQL port (default: 5432)
#   DB_NAME          — Database name (default: pondyconnect)
#   DB_USER          — Database user (default: pondyconnect)
#   PGPASSWORD       — PostgreSQL password (required)
#   GPG_RECIPI       — GPG key ID/email for encryption (required)
#   S3_BUCKET        — S3 bucket for cold storage (optional, skips S3 if unset)
#   AWS_CLI_PROFILE  — AWS CLI profile (default: default)
#   RETENTION_DAYS   — Local backup retention (default: 7)
#   BACKUP_DIR       — Local backup directory (default: /var/backups/pyconnect)

set -euo pipefail

# Load configuration
CONFIG_FILE="${BACKUP_CONFIG:-/etc/pyconnect/backup.env}"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
fi

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-pondyconnect}"
DB_USER="${DB_USER:-pondyconnect}"
GPG_RECIPI="${GPG_RECIPI:-}"
S3_BUCKET="${S3_BUCKET:-}"
AWS_CLI_PROFILE="${AWS_CLI_PROFILE:-default}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/pyconnect}"

# Validate required variables
if [[ -z "$PGPASSWORD" ]]; then
    echo "ERROR: PGPASSWORD is not set" >&2
    exit 1
fi
if [[ -z "$GPG_RECIPI" ]]; then
    echo "ERROR: GPG_RECIPI is not set" >&2
    exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Generate timestamped filename
TIMESTAMP=$(date -u +"%Y%m%d_%H%M%S_UTC")
DUMP_FILE="$BACKUP_DIR/pyconnect_${TIMESTAMP}.sql"
COMPRESSED_FILE="${DUMP_FILE}.gz"
ENCRYPTED_FILE="${COMPRESSED_FILE}.gpg"

echo "[$(date -u)] Starting PY Connect database backup..."
echo "  Database: $DB_NAME at $DB_HOST:$DB_PORT"
echo "  Output:   $ENCRYPTED_FILE"

# Step 1: pg_dump (custom format for parallel restore)
echo "[$(date -u)] Running pg_dump..."
PGPASSWORD="$PGPASSWORD" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --format=custom \
    --compress=9 \
    --no-owner \
    --no-privileges \
    --file="$DUMP_FILE"

if [[ ! -f "$DUMP_FILE" ]]; then
    echo "ERROR: pg_dump failed — no output file produced" >&2
    exit 1
fi

DUMP_SIZE=$(du -h "$DUMP_FILE" | cut -f1)
echo "  pg_dump complete: $DUMP_SIZE"

# Step 2: GPG encrypt (symmetric + asymmetric)
echo "[$(date -u)] Encrypting with GPG (recipient: $GPG_RECIPI)..."
gpg --batch --yes \
    --trust-model always \
    --recipient "$GPG_RECIPI" \
    --output "$ENCRYPTED_FILE" \
    --encrypt "$DUMP_FILE"

if [[ ! -f "$ENCRYPTED_FILE" ]]; then
    echo "ERROR: GPG encryption failed" >&2
    rm -f "$DUMP_FILE"
    exit 1
fi

ENCRYPTED_SIZE=$(du -h "$ENCRYPTED_FILE" | cut -f1)
echo "  Encryption complete: $ENCRYPTED_SIZE"

# Step 3: Remove unencrypted intermediates
rm -f "$DUMP_FILE" "$COMPRESSED_FILE"
echo "  Removed unencrypted intermediates"

# Step 4: Upload to S3 cold storage (if configured)
if [[ -n "$S3_BUCKET" ]]; then
    echo "[$(date -u)] Uploading to S3: s3://$S3_BUCKET/backups/$(basename "$ENCRYPTED_FILE")"
    if aws s3 cp "$ENCRYPTED_FILE" \
        "s3://$S3_BUCKET/backups/$(basename "$ENCRYPTED_FILE")" \
        --profile "$AWS_CLI_PROFILE" \
        --storage-class GLACIER; then
        echo "  S3 upload complete (Glacier cold storage)"
    else
        echo "WARNING: S3 upload failed — local backup retained" >&2
    fi
fi

# Step 5: Clean up old local backups (retain RETENTION_DAYS)
echo "[$(date -u)] Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_DIR" -name "pyconnect_*.gpg" -type f -mtime +"$RETENTION_DAYS" -delete
CLEANED_COUNT=$?
echo "  Retention cleanup complete"

# Step 6: Verify the backup can be decrypted (integrity check)
echo "[$(date -u)] Verifying backup integrity..."
if gpg --batch --decrypt --recipient "$GPG_RECIPI" "$ENCRYPTED_FILE" 2>/dev/null | pg_restore --list >/dev/null 2>&1; then
    echo "  Backup verified: decryptable and valid pg_restore format"
else
    echo "WARNING: Backup integrity check failed — file may be corrupt" >&2
fi

echo "[$(date -u)] Backup complete: $ENCRYPTED_FILE ($ENCRYPTED_SIZE)"
