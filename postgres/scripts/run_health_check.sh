#!/bin/bash
# ============================================================================
# PostgreSQL Health Check Automation
# Purpose: Run health checks and email results
# Usage: ./run_health_check.sh [email]
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
OUTPUT_FILE="${LOG_DIR}/health_$(date +%Y%m%d_%H%M%S).html"
EMAIL_TO="${1:-}"

mkdir -p "${LOG_DIR}"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"

echo "Running PostgreSQL health check..."
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "Database: ${DB_NAME}"

{
    echo "<html><head><title>PostgreSQL Health Report</title></head><body>"
    echo "<h1>PostgreSQL Health Report</h1>"
    echo "<p>Server: ${DB_HOST}:${DB_PORT} | Database: ${DB_NAME} | Time: $(date)</p>"
    echo "<hr>"

    echo "<h2>1. Connection Status</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT state, COUNT(*) FROM pg_stat_activity GROUP BY state;"
    
    echo "<h2>2. Database Sizes</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datistemplate = false ORDER BY pg_database_size(datname) DESC LIMIT 10;"
    
    echo "<h2>3. Table Bloat (Top 10)</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) FROM pg_stat_user_tables WHERE schemaname NOT IN ('pg_catalog','information_schema') ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
    
    echo "<h2>4. Unused Indexes</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT schemaname, tablename, indexname, idx_scan FROM pg_stat_user_indexes WHERE idx_scan = 0 AND indexname NOT LIKE '%pkey%' ORDER BY pg_relation_size(indexname::regclass) DESC LIMIT 10;"
    
    echo "<h2>5. Replication Lag</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT pid, state, (pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024)::numeric FROM pg_stat_replication;"
    
    echo "<h2>6. Slow Queries</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 10;"
    
    echo "<h2>7. Tablespace Usage</h2>"
    psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
        SELECT tablespace_name, pg_size_pretty(SUM(pg_relation_size(schemaname||'.'||tablename))) FROM pg_stat_user_tables GROUP BY tablespace_name;"
    
    echo "<hr><p>Generated: $(date)</p></body></html>"

} > "${OUTPUT_FILE}"

echo "Health check complete. Output: ${OUTPUT_FILE}"

if [[ -n "${EMAIL_TO}" ]]; then
    echo "Sending email to ${EMAIL_TO}..."
    mail -s "PostgreSQL Health Report - ${DB_HOST}" -A "${OUTPUT_FILE}" "${EMAIL_TO}" <<EOF
PostgreSQL health check completed. See attached report.
EOF
    echo "Email sent."
fi
