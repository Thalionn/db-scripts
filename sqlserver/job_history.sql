-- ============================================================================
-- Script: job_history.sql
-- Purpose: Recent SQL Agent job execution status
-- Usage:   Verify nightly jobs completed; check for failures
-- Notes:   Default 24-hour window; adjust as needed
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    j.name AS job_name,
    j.description,
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        WHEN 4 THEN 'In Progress'
    END AS status,
    h.run_date,
    h.run_time,
    h.run_duration,
    h.retries_attempted,
    h.message,
    h.step_id,
    h.step_name
FROM msdb.dbo.sysjobs j
INNER JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.run_date >= CONVERT(INT, CONVERT(VARCHAR, DATEADD(day, -1, GETDATE()), 112))
ORDER BY h.run_date DESC, h.run_time DESC;
