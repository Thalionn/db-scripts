-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.TempDBContentionHistory (
    CaptureID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    WaitType NVARCHAR(100),
    WaitCount BIGINT,
    WaitTimeMs BIGINT,
    AvgWaitMs DECIMAL(10,2)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureTempDBContention
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.TempDBContentionHistory (
        ServerName, WaitType, WaitCount, WaitTimeMs, AvgWaitMs
    )
    SELECT 
        @ServerName,
        wait_type,
        waiting_task_count,
        wait_time_ms,
        CAST(wait_time_ms AS DECIMAL(10,2)) / NULLIF(waiting_task_count, 0)
    FROM sys.dm_os_wait_stats
    WHERE wait_type IN (
        'PAGELATCH_EX', 'PAGELATCH_SH', 'PAGELATCH_UP', 'PAGELATCH_DT',
        'PAGELATCH_KP', 'PAGELATCH_KW', 'PAGELATCH_KR',
        'PAGEIOLATCH_EX', 'PAGEIOLATCH_SH', 'PAGEIOLATCH_UP', 'PAGEIOLATCH_DT',
        'IO_COMPLETION', 'ASYNC_IO_COMPLETION',
        'SOS_SCHEDULER_YIELD', 'THREADPOOL'
    );
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

CREATE OR ALTER VIEW dba.vTempDBContention
AS
SELECT 
    ServerName,
    CaptureTime,
    WaitType,
    WaitCount,
    WaitTimeMs,
    AvgWaitMs,
    CASE
        WHEN WaitType LIKE 'PAGELATCH%' THEN 'LATCH'
        WHEN WaitType LIKE 'PAGEIO%' THEN 'IO'
        WHEN WaitType IN ('SOS_SCHEDULER_YIELD', 'THREADPOOL') THEN 'CPU'
        ELSE 'OTHER'
    END AS Category,
    CASE
        WHEN AvgWaitMs > 100 THEN 'HIGH'
        WHEN AvgWaitMs > 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Severity
FROM dba.TempDBContentionHistory
WHERE CaptureTime >= DATEADD(HOUR, -1, GETDATE())
ORDER BY AvgWaitMs DESC;
GO

CREATE OR ALTER PROCEDURE dba.AnalyzeTempDBContention
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '=== TempDB Contention Analysis ===';
    PRINT '';
    
    -- Current PFS/GAM/SGAM contention
    PRINT '--- Latch Waits on TempDB Files ---';
    SELECT 
        wait_type,
        waiting_task_count AS waiting_tasks,
        wait_time_ms,
        CAST(wait_time_ms * 1.0 / NULLIF(waiting_task_count, 0) AS DECIMAL(10,2)) AS avg_wait_ms
    FROM sys.dm_os_wait_stats
    WHERE wait_type LIKE 'PAGELATCH%'
      AND wait_time_ms > 0
    ORDER BY wait_time_ms DESC;
    
    PRINT '';
    PRINT '--- TempDB File Usage ---';
    
    ;WITH TempDBFiles AS (
        SELECT 
            mf.name AS FileName,
            mf.type,
            mf.size / 128.0 AS SizeMB,
            FILEPROPERTY(mf.name, 'SpaceUsed') / 128.0 AS UsedMB,
            (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS FreeMB,
            mf.size / 128.0 - FILEPROPERTY(mf.name, 'SpaceUsed') / 128.0 AS AvailableMB
        FROM sys.master_files mf
        WHERE mf.database_id = 2
    )
    SELECT 
        FileName,
        SizeMB,
        UsedMB,
        FreeMB,
        CAST(FreeMB * 100.0 / NULLIF(SizeMB, 0) AS DECIMAL(5,2)) AS FreePercent,
        CASE 
            WHEN type = 0 THEN 'Data'
            ELSE 'Log'
        END AS FileType
    FROM TempDBFiles;
    
    PRINT '';
    PRINT '--- Recommended: Create multiple tempdb data files ---';
    PRINT 'If PAGELATCH waits are high, add tempdb data files (1 per CPU core, equal size)';
    PRINT 'Example: ALTER DATABASE tempdb ADD FILE (name = tempdev2, size = 100MB);';
    
    -- Session-level tempdb usage
    PRINT '';
    PRINT '--- Sessions Using TempDB ---';
    SELECT 
        s.session_id,
        s.login_name,
        s.host_name,
        t.text AS QueryText,
        ec.number_of_tempdb_allocations AS TempDBAllocations,
        ec.number_of_tempdb_deallocations AS TempDBDeallocations,
        ec.tempdb_allocations AS TotalAllocations,
        ec.tempdb_deallocations AS TotalDeallocations
    FROM sys.dm_exec_sessions s
    JOIN sys.dm_exec_query_memory_grants mg ON s.session_id = mg.session_id
    CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) t
    JOIN sys.dm_exec_query_stats eqs ON s.session_id = eqs.session_id
    CROSS APPLY sys.dm_exec_query_plan(eqs.plan_handle) p
    CROSS APPLY sys.dm_exec_text_query_plan(eqs.plan_handle, 0, -1) qp
    CROSS APPLY sys.dm_exec_query_statistics_xml(eqs.plan_handle) qs
    OUTER APPLY sys.dm_exec_query_context_settings(qs.context_settings_id) cs
    LEFT JOIN sys.dm_db_task_space_usage ec ON s.session_id = ec.session_id AND ec.request_id = s.request_id
    WHERE s.is_user_process = 1
    ORDER BY ec.number_of_tempdb_allocations DESC;
END
GO

CREATE OR ALTER VIEW dba.vTempDBHealthSummary
AS
SELECT TOP 10
    ServerName,
    CaptureTime,
    WaitType,
    WaitTimeMs,
    AvgWaitMs,
    CASE
        WHEN AvgWaitMs > 100 THEN 'CRITICAL - Investigate immediately'
        WHEN AvgWaitMs > 10 THEN 'WARNING - Monitor closely'
        ELSE 'OK'
    END AS Recommendation
FROM dba.vTempDBContention
ORDER BY AvgWaitMs DESC;
GO

PRINT 'TempDB contention monitoring created.';
PRINT 'Run AnalyzeTempDBContention during performance issues.';
