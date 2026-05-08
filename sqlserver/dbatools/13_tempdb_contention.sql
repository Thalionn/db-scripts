-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

-- Drop table if it exists to allow re-running the script
IF OBJECT_ID('dba.TempDBContentionHistory', 'U') IS NOT NULL
    DROP TABLE dba.TempDBContentionHistory;
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
        waiting_tasks_count,
        wait_time_ms,
        CAST(wait_time_ms AS DECIMAL(10,2)) / NULLIF(waiting_tasks_count, 0)
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
SELECT TOP (100) PERCENT
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
        waiting_tasks_count AS waiting_tasks,
        wait_time_ms,
        CAST(wait_time_ms * 1.0 / NULLIF(waiting_tasks_count, 0) AS DECIMAL(10,2)) AS avg_wait_ms
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
            (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS FreeMB
        FROM sys.master_files mf
        WHERE mf.database_id = 2  -- TempDB is always database_id 2
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

    -- Fixed: Correct session-level TempDB usage query
    PRINT '';
    PRINT '--- Sessions Using TempDB ---';
    SELECT
        s.session_id,
        s.login_name,
        s.host_name,
        COALESCE(
            (su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count) * 8,
            0
        ) AS TempDBUsageKB
    FROM sys.dm_exec_sessions s
    LEFT JOIN sys.dm_db_session_space_usage su ON s.session_id = su.session_id
    WHERE s.is_user_process = 1
      AND COALESCE(
            su.user_objects_alloc_page_count + su.internal_objects_alloc_page_count,
            0
        ) > 0
    ORDER BY TempDBUsageKB DESC;
END
GO

CREATE OR ALTER VIEW dba.vTempDBHealthSummary
AS
SELECT TOP (10)
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
GO
