#!/bin/bash
# ============================================================================
# PostgreSQL Backup Script
# Purpose: Automated backup with retention
# Usage: ./backup.sh [retention_days]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${BACKUP_DIR:-/var/lib/postgresql/backups}"
RETENTION_DAYS="${1:-7}"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/backup_${TIMESTAMP}.sql.gz"

mkdir -p "${BACKUP_DIR}"

echo "Starting PostgreSQL backup..."
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "Output: ${BACKUP_FILE}"

pg_dump -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -Fc | gzip > "${BACKUP_FILE}"

if [ -f "${BACKUP_FILE}" ]; then
    SIZE=$(du -h "${BACKUP_FILE}" | cut -f1)
    echo "Backup complete: ${BACKUP_FILE} (${SIZE})"
else
    echo "ERROR: Backup failed"
    exit 1
fi

echo "Cleaning up backups older than ${RETENTION_DAYS} days..."
find "${BACKUP_DIR}" -name "backup_*.sql.gz" -mtime +${RETENTION_DAYS} -delete

echo "Backup and cleanup complete."
ls -lh "${BACKUP_DIR}" | tail -5
