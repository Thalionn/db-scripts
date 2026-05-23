-- ============================================================================
-- Script: quick_health_check.sql
-- Purpose: Consolidated health check - run this for a fast overview
-- Usage:   Execute entire script or copy sections as needed
-- Notes:   All queries are read-only and safe to run on production
-- ============================================================================

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '============================================================';
PRINT 'SQL Server Quick Health Check';
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Time: ' + CAST(GETDATE() AS VARCHAR);
PRINT '============================================================';
PRINT '';

PRINT '------------------------------------------------------------';
PRINT '1. DATABASE STATUS';
PRINT '------------------------------------------------------------';

SELECT 
    d.name AS DatabaseName,
    d.state_desc AS Status,
    d.recovery_model_desc AS RecoveryModel,
    CAST(SUM(mf.size) OVER(PARTITION BY d.name) * 8 / 1024 AS BIGINT) AS SizeMB,
    d.is_read_only AS ReadOnly,
    d.is_broker_enabled AS BrokerEnabled
FROM sys.databases d
JOIN sys.master_files mf ON d.database_id = mf.database_id
WHERE d.state_desc != 'ONLINE'
ORDER BY d.name;

SELECT COUNT(*) AS OnlineDatabases,
       SUM(CASE WHEN d.recovery_model_desc = 'FULL' THEN 1 ELSE 0 END) AS FullRecovery,
       SUM(CASE WHEN d.recovery_model_desc = 'SIMPLE' THEN 1 ELSE 0 END) AS SimpleRecovery,
       SUM(CASE WHEN d.recovery_model_desc = 'BULK_LOGGED' THEN 1 ELSE 0 END) AS BulkLogged
FROM sys.databases d;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '2. BACKUP STATUS (Last 24 Hours)';
PRINT '------------------------------------------------------------';

SELECT TOP 10
    d.name AS DatabaseName,
    CASE WHEN MAX(b.backup_finish_date) IS NULL THEN 'NEVER' ELSE CAST(MAX(b.backup_finish_date) AS VARCHAR) END AS LastFullBackup,
    DATEDIFF(HOUR, MAX(b.backup_finish_date), GETDATE()) AS HoursSinceBackup,
    CASE 
        WHEN MAX(b.backup_finish_date) IS NULL THEN 'NO BACKUP'
        WHEN DATEDIFF(HOUR, MAX(b.backup_finish_date), GETDATE()) > 24 THEN 'OVERDUE'
        ELSE 'OK'
    END AS BackupStatus
FROM sys.databases d
LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name AND b.type = 'D'
WHERE d.name NOT IN ('model', 'tempdb')
GROUP BY d.name
ORDER BY HoursSinceBackup DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '3. ACTIVE SESSIONS';
PRINT '------------------------------------------------------------';

SELECT TOP 20
    SUBSTRING(sess.program_name, 1, 30) AS Program,
    sess.login_name AS LoginName,
    sess.host_name AS HostName,
    r.status AS Status,
    r.cpu_time AS CPUTime,
    sess.memory_usage AS MemUsage,
    sess.logical_reads AS LogicalReads,
    r.wait_type AS WaitType,
    LEFT(t.text, 50) AS QuerySnippet
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions sess ON r.session_id = sess.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.session_id > 50
ORDER BY r.cpu_time DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '4. TOP WAIT STATS (Last Hour)';
PRINT '------------------------------------------------------------';

SELECT TOP 15
    wait_type,
    waiting_tasks_count AS WaitCount,
    wait_time_ms AS WaitTimeMs,
    signal_wait_time_ms AS SignalWaitMs,
    CAST(wait_time_ms * 100.0 / NULLIF(SUM(wait_time_ms) OVER(), 0) AS DECIMAL(5,2)) AS Pct
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
  AND wait_type NOT IN ('CLR_SEMAPHORE', 'LAZY_WRITER', 'RESOURCE_QUEUE', 'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_INCREMENTAL_FLUSH', 'SQLTRACE_WAIT_ENTRIES', 'WAITFOR', 'BROKER_TASK_STOP', 'BROKER_TO_FLUSH', 'BROKER_TRANSMITTER', 'CHECKPOINT_QUEUE', 'FT_IFTS_SCHEDULER_IDLE_WAIT', 'FT_IFTSHC_MUTEX', 'LOGMGR_QUEUE', 'ONDEMAND_TASK_QUEUE')
ORDER BY wait_time_ms DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '5. BLOCKING CHAINS';
PRINT '------------------------------------------------------------';

SELECT TOP 10
    blocked.session_id AS BlockedSession,
    blocked.status AS BlockedStatus,
    blocked.wait_time AS WaitTimeMs,
    blocked.blocking_session_id AS BlockingSession,
    bs.status AS BlockerStatus,
    bs.login_name AS BlockerLogin,
    bs.program_name AS BlockerProgram,
    blocker.wait_time AS BlockerWaitMs,
    COALESCE(blocked_text.text, '') AS BlockedQuery,
    COALESCE(blocker_text.text, '') AS BlockerQuery
FROM sys.dm_exec_requests blocked
JOIN sys.dm_exec_sessions bs ON blocked.blocking_session_id = bs.session_id
LEFT JOIN sys.dm_exec_requests blocker ON blocked.blocking_session_id = blocker.session_id
CROSS APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text
OUTER APPLY sys.dm_exec_sql_text(blocker.sql_handle) blocker_text
WHERE blocked.session_id > 50
  AND blocked.blocking_session_id > 0
ORDER BY blocked.wait_time DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '6. MISSING INDEXES (Top Impact)';
PRINT '------------------------------------------------------------';

SELECT TOP 10
    OBJECT_NAME(mid.object_id) AS TableName,
    mid.equality_columns,
    mid.inequality_columns,
    mid.included_columns,
    migs.avg_total_user_cost * migs.avg_user_impact / 100.0 AS EstImprovement,
    migs.user_seeks,
    migs.user_scans,
    'CREATE INDEX IX_' + REPLACE(REPLACE(mid.equality_columns, '[', ''), ']', '') + 
    ' ON ' + mid.statement + ' (' + mid.equality_columns + 
    ISNULL(' ' + mid.inequality_columns, '') + ')' + 
    ISNULL(' INCLUDE (' + mid.included_columns + ')', '') AS CreateIndex
FROM sys.dm_db_missing_index_details mid
JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
WHERE migs.avg_user_impact > 10
  AND migs.user_seeks > 50
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '7. LARGE TABLE SCANS';
PRINT '------------------------------------------------------------';

SELECT TOP 10
    OBJECT_NAME(s.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    s.user_scans,
    s.user_seeks,
    s.user_lookups,
    ps.used_page_count * 8 / 1024 AS TableSizeMB,
    CASE 
        WHEN s.user_scans > s.user_seeks * 10 THEN 'SCAN HEAVY'
        ELSE 'OK'
    END AS Recommendation
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
JOIN sys.dm_db_partition_stats ps ON s.object_id = ps.object_id AND s.index_id = ps.index_id
WHERE s.database_id = DB_ID()
  AND OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
  AND ps.used_page_count * 8 / 1024 > 1000
ORDER BY s.user_scans DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '8. TEMPDB USAGE';
PRINT '------------------------------------------------------------';

SELECT 
    f.name AS FileName,
    f.type_desc AS FileType,
    CAST(f.size / 128.0 AS DECIMAL(10,2)) AS SizeMB,
    CAST(fu.allocated_extent_page_count / 128.0 AS DECIMAL(10,2)) AS UsedMB,
    CAST(fu.allocated_extent_page_count * 100.0 / NULLIF(f.size, 0) AS DECIMAL(5,2)) AS PctUsed
FROM tempdb.sys.database_files f
JOIN tempdb.sys.dm_db_file_space_usage fu ON f.file_id = fu.file_id;

SELECT 
    sess.login_name AS LoginName,
    ST.text AS QueryText,
    mg.requested_memory_kb / 1024 AS RequestedMB,
    mg.granted_memory_kb / 1024 AS GrantedMB,
    r.dop AS DOP
FROM sys.dm_exec_sessions sess
JOIN sys.dm_exec_requests r ON sess.session_id = r.session_id
LEFT JOIN sys.dm_exec_query_memory_grants mg ON r.session_id = mg.session_id AND r.request_id = mg.request_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) ST
WHERE sess.session_id > 50
ORDER BY CASE WHEN mg.granted_memory_kb IS NULL THEN 1 ELSE 0 END, mg.granted_memory_kb DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '9. JOB FAILURES (Last 24 Hours)';
PRINT '------------------------------------------------------------';

SELECT TOP 10
    j.name AS JobName,
    jh.run_date,
    jh.run_time,
    jh.run_status,
    jh.message,
    CASE jh.run_status 
        WHEN 0 THEN 'Failed' 
        WHEN 1 THEN 'Succeeded' 
        WHEN 2 THEN 'Retry' 
        WHEN 3 THEN 'Canceled' 
        ELSE 'Unknown' 
    END AS Status
FROM msdb.dbo.sysjobhistory jh
JOIN msdb.dbo.sysjobs j ON jh.job_id = j.job_id
WHERE jh.step_id = 0
  AND jh.run_date >= CONVERT(INT, CONVERT(VARCHAR(8), DATEADD(DAY, -1, GETDATE()), 112))
ORDER BY jh.run_date DESC, jh.run_time DESC;

PRINT '';
PRINT '------------------------------------------------------------';
PRINT '10. ERROR LOG RECENT ERRORS';
PRINT '------------------------------------------------------------';
PRINT '';

IF OBJECT_ID('tempdb..#ErrorLog') IS NOT NULL DROP TABLE #ErrorLog;
CREATE TABLE #ErrorLog (LogDate DATETIME, ProcessInfo NVARCHAR(50), Text NVARCHAR(MAX));

-- fn_vw_error_log provides better access than xp_readerrorlog for recent errors
SELECT TOP 10 INTO #ErrorLog WITH NOLOCK 
    error_date AS LogDate,
    process_info,
    message AS Text
FROM ::fn_vw_error_log;

IF @@ROWCOUNT = 0
BEGIN
    PRINT 'Note: Error log query returned no results.';
    SELECT TOP 10 DATEADD(SECOND, -1 * (24*3600), GETDATE()) AS LogDate, 'N/A' AS Text FROM sys.databases WHERE 1=0;
END

SELECT TOP 10
    LogDate,
    LEFT(Text, 80) AS Message
FROM #ErrorLog
WHERE Text LIKE '%Error%' OR Text LIKE '%Failed%' OR Text LIKE '%Severity%'
ORDER BY LogDate DESC;
DROP TABLE #ErrorLog;

PRINT '';
PRINT '============================================================';
PRINT 'Health Check Complete';
PRINT '============================================================';
