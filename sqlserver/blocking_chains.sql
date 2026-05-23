-- ============================================================================
-- Script: blocking_chains.sql
-- Purpose: Visualize blocking session trees
-- Usage:   Run during incidents to identify head blockers
-- Notes:   Uses recursive CTE to show full blocking chain; 
--         Head blocker = root cause of blocking chain
-- ============================================================================

SET NOCOUNT ON;

WITH BlockingChain (blocked_spid, blocking_spid, level)
AS (
    SELECT 
        s.session_id AS blocked_spid,
        s.blocking_session_id AS blocking_spid,
        0 AS level
    FROM sys.dm_exec_requests s
    WHERE s.blocking_session_id IS NOT NULL AND s.blocking_session_id > 0

    UNION ALL

    SELECT 
        r.session_id,
        r.blocking_session_id,
        bc.level + 1
    FROM sys.dm_exec_requests r
    INNER JOIN BlockingChain bc ON r.session_id = CAST(bc.blocking_spid AS INT)
    WHERE r.blocking_session_id IS NOT NULL AND r.blocking_session_id > 0
      AND bc.level < 95 -- Prevent stack overflow on deep chains
)
SELECT 
    bc.blocked_spid AS blocked_spid,
    COALESCE(bc.blocking_spid, -1) AS blocked_by,
    bc.level,
    REPLICATE('  ', bc.level) + CAST(bc.blocked_spid AS VARCHAR(10)) AS chain,
    s.login_name,
    s.status,
    r.wait_type,
    r.wait_time,
    r.cpu_time,
    DB_NAME(r.database_id) AS database_name,
    LEFT(t.text, 150) AS current_query
FROM BlockingChain bc
JOIN sys.dm_exec_sessions s ON bc.blocked_spid = s.session_id
JOIN sys.dm_exec_requests r ON bc.blocked_spid = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
ORDER BY bc.level DESC, bc.blocked_spid DESC;

PRINT '';
PRINT 'INTERPRETATION:';
PRINT '- level 0: Head blocker (root cause of blocking chain)';
PRINT '- Positive blocked_by means "session X is blocked by session Y"';
PRINT '- Focus on fixing the head blocker first for maximum impact.';
