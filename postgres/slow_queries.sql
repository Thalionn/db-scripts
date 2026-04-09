-- ============================================================================
-- Script: slow_queries.sql
-- Purpose: Identify currently running slow queries
-- Usage:   Kill problematic queries if needed (see below)
-- Notes:   Adjust the 30-second threshold as needed
-- ============================================================================

SELECT 
    pid,
    now() - query_start AS running_time,
    state,
    usename,
    query,
    left(query, 100) AS query_preview
FROM pg_stat_activity
WHERE state != 'idle'
  AND query_start < NOW() - INTERVAL '30 seconds'
ORDER BY query_start;
