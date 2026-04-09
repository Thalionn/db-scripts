-- ============================================================================
-- Script: active_sessions.sql
-- Purpose: Current SPID inventory with wait info
-- Usage:   Quick overview of what's running on the instance
-- Notes:   Excludes system SPIDs; includes transaction info
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    s.session_id AS spid,
    s.login_name AS login_name,
    s.host_name AS client,
    s.program_name,
    s.database_id,
    DB_NAME(s.database_id) AS database_name,
    s.status,
    s.cpu_time,
    s.memory_usage,
    s.total_elapsed_time,
    s.reads,
    s.writes,
    s.wait_type,
    s.wait_time,
    s.blocking_session_id AS blocked_by,
    LEFT(c.text, 100) AS current_query
FROM sys.dm_exec_sessions s
LEFT JOIN sys.dm_exec_connections c 
    ON s.session_id = c.session_id
WHERE s.is_user_process = 1
ORDER BY s.status, s.session_id;
