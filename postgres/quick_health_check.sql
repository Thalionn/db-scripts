-- ============================================================================
-- Script: quick_health_check.sql
-- Purpose: Consolidated health check for PostgreSQL
-- Usage:   psql -f quick_health_check.sql
-- Notes:   Run as superuser for full results
-- ============================================================================

\echo '============================================================'
\echo 'PostgreSQL Quick Health Check'
\echo 'Server: ' || current_setting('server_version') || ' / ' || current_database()
\echo 'Time: ' || now()
\echo '============================================================'
\echo ''

\echo '------------------------------------------------------------'
\echo '1. DATABASE STATUS'
\echo '------------------------------------------------------------'

SELECT 
    datname AS DatabaseName,
    datconnlimit AS MaxConnections,
    datistemplate AS IsTemplate,
    datallowconn AS AllowConn
FROM pg_database
WHERE datistemplate = false
ORDER BY datname;

\echo ''
\echo '------------------------------------------------------------'
\echo '2. CONNECTION STATUS'
\echo '------------------------------------------------------------'

SELECT 
    state,
    COUNT(*) AS ConnectionCount,
    MAX(EXTRACT(EPOCH FROM (now() - state_change))) AS MaxDurationSec
FROM pg_stat_activity
GROUP BY state
ORDER BY state;

SELECT 
    application_name AS Application,
    usename AS UserName,
    client_addr AS ClientIP,
    state,
    wait_event_type || ':' || wait_event AS WaitEvent,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND pid != pg_backend_pid()
ORDER BY query_start;

\echo ''
\echo '------------------------------------------------------------'
\echo '3. REPLICATION STATUS'
\echo '------------------------------------------------------------'

SELECT 
    pid,
    usesysid,
    usename,
    application_name,
    client_addr,
    backend_start,
    backend_xmin,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    (pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) / 1024 / 1024)::numeric AS ReplayLagMB
FROM pg_stat_replication
ORDER BY backend_start;

\echo ''
\echo '------------------------------------------------------------'
\echo '4. TOP WAIT EVENTS'
\echo '------------------------------------------------------------'

SELECT 
    wait_event_type,
    wait_event,
    COUNT(*) AS WaitCount
FROM pg_stat_activity
WHERE wait_event_type IS NOT NULL
  AND pid != pg_backend_pid()
GROUP BY wait_event_type, wait_event
ORDER BY WaitCount DESC;

\echo ''
\echo '------------------------------------------------------------'
\echo '5. SLOW QUERIES (Last 30 min with pg_stat_statements)'
\echo '------------------------------------------------------------'

SELECT 
    calls,
    total_exec_time / 1000 AS TotalTimeSec,
    mean_exec_time AS MeanTimeMs,
    rows,
    query
FROM pg_stat_statements
ORDER BY total_exec_time DESC
LIMIT 20;

\echo ''
\echo '------------------------------------------------------------'
\echo '6. TABLE BLOAT'
\echo '------------------------------------------------------------'

SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS TotalSize,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS TableSize,
    CASE 
        WHEN pg_total_relation_size(schemaname||'.'||tablename) > 0
        THEN ROUND((pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) * 100.0 / pg_total_relation_size(schemaname||'.'||tablename), 1)
        ELSE 0
    END AS PctBloat
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND pg_total_relation_size(schemaname||'.'||tablename) > 1024*1024
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
LIMIT 20;

\echo ''
\echo '------------------------------------------------------------'
\echo '7. UNUSED INDEXES'
\echo '------------------------------------------------------------'

SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS IndexSize,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED'
        WHEN idx_scan < 10 THEN 'LOW USAGE'
        ELSE 'ACTIVE'
    END AS Status
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND indexname NOT LIKE '%pkey%'
ORDER BY idx_scan ASC, pg_relation_size(indexname::regclass) DESC
LIMIT 20;

\echo ''
\echo '------------------------------------------------------------'
\echo '8. TABLESPACE USAGE'
\echo '------------------------------------------------------------'

SELECT 
    tablespace_name,
    pg_size_pretty(SUM(pg_relation_size(schemaname||'.'||tablename))) AS TotalUsed,
    COUNT(*) AS TableCount
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
GROUP BY tablespace_name
ORDER BY SUM(pg_relation_size(schemaname||'.'||tablename)) DESC;

\echo ''
\echo '------------------------------------------------------------'
\echo '9. LONG RUNNING QUERIES'
\echo '------------------------------------------------------------'

SELECT 
    pid,
    usename,
    application_name,
    state,
    EXTRACT(EPOCH FROM (now() - query_start)) AS DurationSec,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < now() - INTERVAL '5 minutes'
ORDER BY query_start;

\echo ''
\echo '------------------------------------------------------------'
\echo '10. INDEX HIT RATIO'
\echo '------------------------------------------------------------'

SELECT 
    schemaname,
    relname,
    heap_blks_read,
    heap_blks_hit,
    ROUND(heap_blks_hit * 100.0 / NULLIF(heap_blks_hit + heap_blks_read, 0), 2) AS hit_ratio
FROM pg_statio_user_tables
ORDER BY heap_blks_read DESC
LIMIT 10;

\echo ''
\echo '============================================================'
\echo 'Health Check Complete'
\echo '============================================================'
