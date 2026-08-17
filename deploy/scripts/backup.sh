#!/bin/bash
set -e

# Configuration
DB_NAME="${POSTGRES_DB:-pondyconnect}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_HOST="${POSTGRES_HOST:-localhost}"
DB_PORT="${POSTGRES_PORT:-5432}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/pondyconnect}"
S3_BUCKET="${S3_BUCKET:-}"
AWS_PROFILE="${AWS_PROFILE:-default}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/pondyconnect_${DATE}.sql"
COMPRESSED_FILE="${BACKUP_FILE}.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Run pg_dump
echo "Backing up database ${DB_NAME}..."
PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -F p \
    -f "$BACKUP_FILE"

# Compress
echo "Compressing backup..."
gzip "$BACKUP_FILE"

# Upload to S3 if bucket configured
if [ -n "$S3_BUCKET" ]; then
    echo "Uploading to S3..."
    aws s3 cp "$COMPRESSED_FILE" "s3://${S3_BUCKET}/backups/" --profile "$AWS_PROFILE"
fi

# Clean up old local backups
find "$BACKUP_DIR" -name "pondyconnect_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete

echo "Backup completed: $COMPRESSED_FILE"
