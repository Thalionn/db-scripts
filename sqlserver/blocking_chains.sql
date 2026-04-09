-- ============================================================================
-- Script: blocking_chains.sql
-- Purpose: Visualize blocking session trees
-- Usage:   Run during incidents to identify head blockers
-- Notes:   Uses recursive CTE to show full blocking chain
-- ============================================================================

SET NOCOUNT ON;

WITH BlockingChain (blocked_spid, blocking_spid, level, query_text)
AS (
    SELECT 
        s.session_id AS blocked_spid,
        s.blocking_session_id AS blocking_spid,
        0 AS level,
        CAST('' AS VARCHAR(MAX))
    FROM sys.dm_exec_requests s
    WHERE s.blocking_session_id > 0
    
    UNION ALL
    
    SELECT 
        r.session_id,
        r.blocking_session_id,
        bc.level + 1,
        bc.query_text
    FROM sys.dm_exec_requests r
    INNER JOIN BlockingChain bc ON r.session_id = bc.blocking_spid
    WHERE r.blocking_session_id > 0
)
SELECT 
    bc.blocked_spid AS blocked_spid,
    bc.blocking_spid AS blocked_by,
    bc.level,
    REPLICATE('  ', bc.level) + CAST(bc.blocked_spid AS VARCHAR(10)) AS chain,
    s.login_name,
    s.status,
    s.wait_type,
    s.wait_time,
    s.cpu_time,
    DB_NAME(r.database_id) AS database_name,
    LEFT(r.text, 150) AS current_query
FROM BlockingChain bc
JOIN sys.dm_exec_sessions s ON bc.blocked_spid = s.session_id
JOIN sys.dm_exec_requests r ON bc.blocked_spid = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
ORDER BY bc.level, bc.blocked_spid;
