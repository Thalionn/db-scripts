-- ============================================================================
-- Script: sessions_active.sql
-- Purpose: Current active session inventory by user and program
-- Usage:   Run during peak hours to identify connection distribution
-- Notes:   Filters out recursive SQL and background processes
-- ============================================================================

SET LINESIZE 200 PAGESIZE 50
COLUMN username FORMAT A20
COLUMN program FORMAT A40
COLUMN machine FORMAT A25
COLUMN status FORMAT A10

SELECT 
    s.username,
    s.program,
    s.machine,
    s.status,
    COUNT(*) AS session_count,
    MAX(s.logon_time) AS last_login
FROM v$session s
WHERE s.username IS NOT NULL
  AND s.type = 'USER'
  AND s.program NOT LIKE '%(PZ%)'
GROUP BY s.username, s.program, s.machine, s.status
ORDER BY session_count DESC, s.username;
