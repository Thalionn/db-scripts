-- ============================================================================
-- Script: sessions_current.sql
-- Purpose: Active connection overview by database and state
-- Usage:   Quick health check on connection limits
-- Notes:   Shows wait status and current query for blocked sessions
-- ============================================================================

SELECT 
    p.datname AS database_name,
    a.state,
    a.query,
    a.query_start,
    NOW() - a.query_start AS duration,
    a.wait_event_type,
    a.wait_event,
    p.usename AS username,
    p.client_addr,
    p.application_name,
    p.pid
FROM pg_stat_activity a
JOIN pg_stat_get_activity(pg_backend_pid()) p ON a.pid = p.pid
WHERE a.pid IS NOT NULL
ORDER BY a.state, duration DESC;
