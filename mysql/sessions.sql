-- ============================================================================
-- Script: sessions.sql
-- Purpose: Current thread/connection inventory
-- Usage:   Check for connection pool exhaustion or runaway queries
-- Notes:   Filter 'Sleep' rows to focus on active queries
-- ============================================================================

SELECT 
    p.id AS thread_id,
    p.user AS username,
    p.host,
    p.db AS database,
    p.command AS command,
    p.time AS duration_sec,
    LEFT(p.info, 100) AS current_query,
    p.state,
    p.Time AS query_duration,
    UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(p.time) AS idle_seconds
FROM information_schema.processlist p
WHERE p.user != 'event_scheduler'
ORDER BY 
    CASE p.command WHEN 'Sleep' THEN 1 ELSE 0 END,
    p.time DESC;
