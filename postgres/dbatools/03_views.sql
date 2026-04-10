-- ============================================================================
-- Script: 03_views.sql
-- Purpose: Diagnostic views for DBATools
-- Usage:   Run after 02_functions.sql for quick analysis
-- ============================================================================

-- Current wait events
CREATE OR REPLACE VIEW dba.v_current_waits AS
SELECT 
    p.pid,
    p.usename,
    p.application_name,
    p.state,
    p.wait_event_type,
    p.wait_event,
    p.query_start,
    NOW() - p.query_start AS duration,
    LEFT(p.query, 200) AS query_preview
FROM pg_stat_activity p
WHERE p.state != 'idle'
  AND p.pid <> pg_backend_pid()
ORDER BY p.query_start;

-- Wait stats summary
CREATE OR REPLACE VIEW dba.v_wait_stats_summary AS
SELECT 
    w.wait_type,
    SUM(w.wait_count) AS total_waits,
    SUM(w.wait_time_ms) AS total_wait_ms,
    AVG(w.wait_time_ms) AS avg_wait_ms,
    SUM(w.signal_wait_time_ms) AS total_signal_wait_ms,
    CASE 
        WHEN w.wait_type LIKE '%Lock%' THEN 'Lock'
        WHEN w.wait_type LIKE '%Buffer%' THEN 'Buffer'
        WHEN w.wait_type LIKE '%WAL%' THEN 'WAL'
        WHEN w.wait_type LIKE '%IO%' THEN 'IO'
        WHEN w.wait_type LIKE '%Lock%' THEN 'Lock'
        WHEN w.wait_type LIKE '%LWLock%' THEN 'LWLock'
        WHEN w.wait_type = 'Activity' THEN 'Idle'
        ELSE 'Other'
    END AS category
FROM dba.wait_stats_history w
WHERE w.capture_time >= NOW() - INTERVAL '1 hour'
GROUP BY w.wait_type
ORDER BY SUM(w.wait_time_ms) DESC;

-- Blocking sessions
CREATE OR REPLACE VIEW dba.v_blocking_sessions AS
SELECT 
    blocked.pid AS blocked_pid,
    blocked.usename AS blocked_user,
    LEFT(blocked.query, 100) AS blocked_query,
    blocker.pid AS blocking_pid,
    blocker.usename AS blocking_user,
    blocker.query AS blocking_query,
    blocked.query_start AS blocked_since,
    NOW() - blocked.query_start AS wait_duration
FROM pg_stat_activity blocked
JOIN pg_stat_activity blocker ON blocked.blocking_pid = blocker.pid
WHERE blocked.blocking_pid > 0
  AND blocked.pid <> pg_backend_pid();

-- Database sizes trend
CREATE OR REPLACE VIEW dba.v_database_size_trend AS
SELECT 
    datname,
    capture_time::DATE AS snapshot_date,
    AVG(size_mb) AS avg_size_mb,
    MIN(size_mb) AS min_size_mb,
    MAX(size_mb) AS max_size_mb
FROM dba.database_size_history
GROUP BY datname, capture_time::DATE
ORDER BY datname, capture_time::DATE DESC;

-- Table bloat detection
CREATE OR REPLACE VIEW dba.v_table_bloat AS
SELECT 
    schemaname,
    relname AS tablename,
    n_live_tup,
    n_dead_tup,
    CASE WHEN n_live_tup > 0 
         THEN ROUND(100.0 * n_dead_tup / (n_live_tup + n_dead_tup), 2)
         ELSE 0 
    END AS dead_tuple_pct,
    pg_total_relation_size(schemaname || '.' || relname) / 1024 / 1024 AS total_size_mb,
    pg_relation_size(schemaname || '.' || relname) / 1024 / 1024 AS table_size_mb,
    pg_indexes_size(schemaname || '.' || relname) / 1024 / 1024 AS index_size_mb
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY n_dead_tup DESC;

-- Unused indexes
CREATE OR REPLACE VIEW dba.v_unused_indexes AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_relation_size(schemaname || '.' || indexname) / 1024 / 1024 AS index_size_mb,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED - DROP CANDIDATE'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        ELSE 'ACTIVE'
    END AS status
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND indexname NOT LIKE '%pkey%'
ORDER BY idx_scan ASC NULLS FIRST;

-- Replication lag status
CREATE OR REPLACE VIEW dba.v_replication_status AS
SELECT 
    client_addr,
    state,
    sync_state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    CASE 
        WHEN pg_wal_lsn_diff(sent_lsn, replay_lsn) > 1073741824 THEN 'CRITICAL'  -- 1GB
        WHEN pg_wal_lsn_diff(sent_lsn, replay_lsn) > 104857600 THEN 'WARNING'   -- 100MB
        ELSE 'OK'
    END AS status
FROM pg_stat_replication;

-- Failed logins (last 24 hours)
CREATE OR REPLACE VIEW dba.v_failed_logins_24h AS
SELECT 
    username,
    client_addr,
    COUNT(*) AS failed_attempts,
    MIN(audit_time) AS first_attempt,
    MAX(audit_time) AS last_attempt,
    NOW() - MAX(audit_time) AS time_since_last
FROM dba.login_audit
WHERE event_type = 'FAILED_LOGIN'
  AND audit_time >= NOW() - INTERVAL '24 hours'
GROUP BY username, client_addr
HAVING COUNT(*) >= 3
ORDER BY failed_attempts DESC;

-- Connection summary
CREATE OR REPLACE VIEW dba.v_connection_summary AS
SELECT 
    state,
    COUNT(*) AS connection_count,
    COUNT(DISTINCT usename) AS unique_users,
    COUNT(DISTINCT application_name) AS unique_apps
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
GROUP BY state
ORDER BY connection_count DESC;

-- Slow queries (from current stats)
CREATE OR REPLACE VIEW dba.v_slow_queries AS
SELECT 
    queryid,
    LEFT(query, 200) AS query_preview,
    calls,
    total_time_ms,
    mean_time_ms,
    max_time_ms,
    rows,
    shared_blks_hit,
    shared_blks_read,
    CASE 
        WHEN mean_time_ms > 1000 THEN 'HIGH DURATION'
        WHEN shared_blks_read > 10000 THEN 'HIGH READS'
        WHEN calls > 10000 THEN 'HIGH FREQUENCY'
        ELSE 'Other'
    END AS issue_type
FROM pg_stat_statements
WHERE calls > 0
ORDER BY total_time_ms DESC
LIMIT 50;

-- Cache hit ratio by database
CREATE OR REPLACE VIEW dba.v_cache_hit_ratio AS
SELECT 
    schemaname,
    relname AS tablename,
    heap_blks_hit,
    heap_blks_read,
    heap_blks_hit + heap_blks_read AS total_blks,
    CASE 
        WHEN heap_blks_hit + heap_blks_read > 0 
        THEN ROUND(100.0 * heap_blks_hit / (heap_blks_hit + heap_blks_read), 2)
        ELSE 100
    END AS cache_hit_ratio
FROM pg_statio_user_tables
WHERE heap_blks_read > 0
ORDER BY cache_hit_ratio ASC;

-- Index maintenance recommendations
CREATE OR REPLACE VIEW dba.v_index_maintenance_needed AS
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    pg_relation_size(schemaname || '.' || indexname) / 1024 / 1024 AS index_size_mb,
    CASE
        WHEN idx_scan = 0 AND pg_relation_size(schemaname || '.' || indexname) / 1024 / 1024 > 10 
        THEN 'DROP - Unused and large'
        WHEN idx_scan < 100 AND pg_relation_size(schemaname || '.' || indexname) / 1024 / 1024 > 5
        THEN 'Review - Low usage'
        ELSE 'OK'
    END AS recommendation
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND indexname NOT LIKE '%pkey%'
  AND indexname NOT LIKE '%fkey%';

-- Database growth projection
CREATE OR REPLACE VIEW dba.v_database_growth AS
WITH daily_sizes AS (
    SELECT 
        datname,
        capture_time::DATE AS snapshot_date,
        size_mb
    FROM dba.database_size_history
    WHERE capture_time >= NOW() - INTERVAL '30 days'
),
growth_rates AS (
    SELECT 
        datname,
        (MAX(size_mb) - MIN(size_mb)) / NULLIF(EXTRACT(DAY FROM MAX(capture_time) - MIN(capture_time)), 0) AS daily_growth_mb,
        MAX(size_mb) AS current_size_mb,
        MAX(capture_time) AS last_capture
    FROM dba.database_size_history
    WHERE capture_time >= NOW() - INTERVAL '30 days'
    GROUP BY datname
)
SELECT 
    gr.datname,
    gr.current_size_mb,
    gr.daily_growth_mb,
    CASE 
        WHEN gr.daily_growth_mb > 0 
        THEN ROUND(gr.current_size_mb / gr.daily_growth_mb, 0)
        ELSE NULL 
    END AS days_to_double,
    CASE
        WHEN gr.daily_growth_mb > 1024 THEN 'CRITICAL'
        WHEN gr.daily_growth_mb > 512 THEN 'WARNING'
        WHEN gr.daily_growth_mb > 100 THEN 'MONITOR'
        ELSE 'OK'
    END AS status
FROM growth_rates gr
ORDER BY gr.daily_growth_mb DESC NULLS LAST;

-- Server inventory summary
CREATE OR REPLACE VIEW dba.v_server_overview AS
SELECT 
    si.server_name,
    si.environment,
    si.is_active,
    si.date_added,
    COALESCE(cs.connection_count, 0) AS current_connections,
    COALESCE(la.failed_logins_24h, 0) AS failed_logins_24h,
    COALESCE(ds.max_size_mb, 0) AS largest_db_mb,
    COALESCE(
        (SELECT MAX(lag_bytes) / 1024 / 1024 FROM dba.v_replication_status),
        0
    ) AS max_replication_lag_mb
FROM dba.server_inventory si
LEFT JOIN (
    SELECT COUNT(*) AS connection_count FROM pg_stat_activity WHERE pid <> pg_backend_pid()
) cs ON TRUE
LEFT JOIN (
    SELECT COUNT(*) AS failed_logins_24h 
    FROM dba.login_audit 
    WHERE event_type = 'FAILED_LOGIN' 
      AND audit_time >= NOW() - INTERVAL '24 hours'
) la ON TRUE
LEFT JOIN (
    SELECT MAX(size_mb) AS max_size_mb FROM dba.database_size_history
) ds ON TRUE;

RAISE NOTICE 'Views created successfully.';
