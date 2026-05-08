-- ============================================================================
-- Script: autogrowth_events.sql
-- Purpose: Audit autogrowth events (requires trace flag)
-- Usage:   Identify databases causing fragmentation via autogrowth
-- Notes:   Enable trace flag for extended events capture
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    DatabaseID,
    DB_NAME(DatabaseID) AS database_name,
    FileName,
    StartTime,
    EndTime,
    Duration,
    CASE EventClass
        WHEN 92 THEN 'Autogrowth'
        WHEN 93 THEN 'Shrink'
    END AS event_type,
    CASE 
        WHEN EventClass = 92 THEN (IntegerData * 8.0 / 1024)
    END AS growth_mb
FROM fn_trace_gettable(
    (SELECT path FROM sys.traces WHERE is_default = 1), 
    DEFAULT
)
WHERE EventClass IN (92, 93)
  AND DATEDIFF(day, StartTime, GETDATE()) <= 7
ORDER BY StartTime DESC;
