-- ============================================================================
-- Script: autogrowth_events.sql
-- Purpose: Audit autogrowth events (requires trace flag)
-- Usage:   Identify databases causing fragmentation via autogrowth
-- Notes:   Enable trace flag for extended events capture
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    TRCE.DatabaseID,
    DB_NAME(TRCE.DatabaseID) AS database_name,
    FileName,
    StartTime,
    EndTime,
    Duration,
    CASE TRCE.EventClass
        WHEN 92 THEN 'Autogrowth'
        WHEN 93 THEN 'Shrink'
    END AS event_type,
    CASE 
        WHEN TRCE.EventClass = 92 THEN (TRCE.IntegerData * 8.0 / 1024)
    END AS growth_mb
FROM fn_trace_gettable(
    (SELECT TR.path FROM sys.traces WHERE is_default = 1), 
    DEFAULT
) TRCE
WHERE TRCE.EventClass IN (92, 93)
  AND DATEDIFF(day, TRCE.StartTime, GETDATE()) <= 7
ORDER BY TRCE.StartTime DESC;

IF @@ROWCOUNT = 0
BEGIN
    PRINT 'No autogrowth events found in trace files.';
    PRINT 'Enable Trace Flag 1233 to capture autogrowth events.';
    PRINT 'Or use sys.dm_os_wait_stats with wait_type LIKE ''PAGEIOLATCH_%%'' for I/O analysis.';
END;
