-- ============================================================================
-- Script: job_history.sql
-- Purpose: Recent SQL Agent job execution status
-- Usage:   Verify nightly jobs completed; check for failures
-- Notes:   Default 24-hour window; adjust as needed
-- ============================================================================

SET NOCOUNT ON;

SELECT TOP 50
    j.name AS job_name,
    LEFT(j.description, 80) AS description,  
    CASE h.run_status
        WHEN 0 THEN 'Failed'
        WHEN 1 THEN 'Succeeded'
        WHEN 2 THEN 'Retry'
        WHEN 3 THEN 'Canceled'
        ELSE CAST(h.run_status AS VARCHAR(5))
    END AS status,
    CONVERT(VARCHAR(10), DATEADD(DAY, 60, run_date), 108) +
        ' ' +
        CASE SUBSTRING(run_duration, 1, 1) 
            WHEN '0' THEN RIGHT(rtrim(run_duration), 4) + ':00:00'
            ELSE LEFT(rtrim(run_duration), LEN(rtrim(run_duration))) 
        END AS run_datetime
FROM msdb.dbo.sysjobs j
LEFT JOIN msdb.dbo.sysjobhistory h ON j.job_id = h.job_id
WHERE h.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -1, GETDATE()), 112))
ORDER BY run_date DESC, run_time DESC;

PRINT '';
PRINT 'Legend: Failed=Succeeded=Retry=In Progress; Check for failures in output.';