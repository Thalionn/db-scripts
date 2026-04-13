#!/bin/bash
# ============================================================================
# PostgreSQL Index Maintenance Script
# Purpose: Analyze tables and rebuild bloated indexes
# Usage: ./index_maintenance.sh
# ============================================================================

set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-postgres}"
DB_USER="${DB_USER:-postgres}"

echo "Running PostgreSQL index maintenance..."

echo "Step 1: ANALYZE tables..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -c "
    SELECT 'ANALYZE ' || schemaname || '.' || tablename 
    FROM pg_tables 
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
    ORDER BY schemaname, tablename;" -t | psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}"

echo "Step 2: Tables with bloat (top 20)..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
    SELECT 
        schemaname || '.' || tablename AS table_name,
        pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS total_size,
        CASE 
            WHEN pg_total_relation_size(schemaname||'.'||tablename) > 0
            THEN ROUND((pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) * 100.0 / pg_total_relation_size(schemaname||'.'||tablename), 1)
            ELSE 0
        END AS pct_bloat
    FROM pg_stat_user_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND pg_total_relation_size(schemaname||'.'||tablename) > 1024*1024
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 20;"

echo "Step 3: Unused indexes (consider dropping)..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
    SELECT 
        schemaname || '.' || tablename AS table_name,
        indexname,
        pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size,
        idx_scan,
        CASE 
            WHEN idx_scan = 0 THEN 'DROP CANDIDATE'
            WHEN idx_scan < 10 THEN 'LOW USAGE'
            ELSE 'OK'
        END AS recommendation
    FROM pg_stat_user_indexes
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND indexname NOT LIKE '%pkey%'
    ORDER BY idx_scan ASC, pg_relation_size(indexname::regclass) DESC
    LIMIT 20;"

echo "Step 4: Missing indexes (high write tables)..."
psql -h "${DB_HOST}" -p "${DB_PORT}" -U "${DB_USER}" -d "${DB_NAME}" -t -c "
    SELECT 
        schemaname || '.' || relname AS table_name,
        seq_scan,
        seq_tup_read,
        idx_scan,
        idx_tup_fetch,
        n_tup_ins,
        n_tup_upd,
        n_tup_del
    FROM pg_stat_user_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
      AND (n_tup_ins + n_tup_upd + n_tup_del) > 1000
      AND seq_scan > idx_scan * 10
    ORDER BY seq_scan DESC
    LIMIT 10;"

echo "Index maintenance check complete."
