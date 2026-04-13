#!/bin/bash
# ============================================================================
# PostgreSQL Cron Setup
# Purpose: Install cron jobs for automated maintenance
# Usage: ./setup_cron.sh
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CRON_USER="${CRON_USER:-postgres}"
CRON_SCHEDULE_HEALTH="${CRON_SCHEDULE_HEALTH:-0 */6 * * *}"
CRON_SCHEDULE_BACKUP="${CRON_SCHEDULE_BACKUP:-0 2 * * *}"
CRON_SCHEDULE_INDEX="${CRON_SCHEDULE_INDEX:-0 3 * * 0}"

BACKUP_DIR="${BACKUP_DIR:-/var/lib/postgresql/backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

CRON_FILE="/tmp/pg_cron_$$.tmp"

cat > "${CRON_FILE}" <<EOF
# PostgreSQL Maintenance Cron Jobs
# Generated: $(date)

# Health check every 6 hours
${CRON_SCHEDULE_HEALTH} cd ${SCRIPT_DIR} && ./run_health_check.sh

# Daily backup at 2 AM
${CRON_SCHEDULE_BACKUP} cd ${SCRIPT_DIR} && ./backup.sh ${RETENTION_DAYS}

# Weekly index maintenance on Sunday at 3 AM
${CRON_SCHEDULE_INDEX} cd ${SCRIPT_DIR} && ./index_maintenance.sh

EOF

echo "Cron jobs to be installed:"
echo "-------------------------------------------"
cat "${CRON_FILE}"
echo "-------------------------------------------"

read -p "Install these cron jobs for user '${CRON_USER}'? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    crontab -u "${CRON_USER}" "${CRON_FILE}"
    echo "Cron jobs installed for user: ${CRON_USER}"
    crontab -u "${CRON_USER}" -l
else
    echo "Installation cancelled."
fi

rm -f "${CRON_FILE}"
