-- ============================================================================
-- Script: optimal_settings.sql
-- Purpose: Display and recommend SQL Server best practice settings
-- Usage:   Review output before making changes; some require restart
-- Notes:   READ-ONLY — this script only prints recommendations, it does
--          not apply any settings automatically.
-- ============================================================================

SET NOCOUNT ON;

PRINT REPLICATE('=', 60);
PRINT 'SQL Server Optimal Configuration Review';
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Time: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT REPLICATE('=', 60);
PRINT '';

-- ============================================================================
-- SECTION 0: Preflight Checks
-- ============================================================================
PRINT '--- SECTION 0: Preflight Checks ---';
PRINT '';

DECLARE @ServerEdition       NVARCHAR(100) = CAST(SERVERPROPERTY('EDITION') AS NVARCHAR(100));
DECLARE @EngineEdition       INT           = CAST(SERVERPROPERTY('EngineEdition') AS INT);
DECLARE @ProductVersion      NVARCHAR(100) = CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(100));
DECLARE @TotalRAM_GB         INT;
DECLARE @CPUCount            INT;
DECLARE @DatabaseCount       INT;

SELECT @TotalRAM_GB = total_physical_memory_kb / 1024 / 1024 FROM sys.dm_os_sys_info;
SELECT @CPUCount    = cpu_count FROM sys.dm_os_sys_info;
SELECT @DatabaseCount = COUNT(*) FROM sys.databases WHERE state = 0;

PRINT '  Edition:             ' + @ServerEdition;
PRINT '  Engine Edition:      ' + CAST(@EngineEdition AS VARCHAR);
PRINT '  Product Version:     ' + @ProductVersion;
PRINT '  Total RAM (GB):      ' + CAST(@TotalRAM_GB AS VARCHAR);
PRINT '  CPU Count:           ' + CAST(@CPUCount AS VARCHAR);
PRINT '  Online Databases:    ' + CAST(@DatabaseCount AS VARCHAR);
PRINT '';

-- ============================================================================
-- SECTION 1: Instance-Level Settings (Read-Only Review)
-- ============================================================================
PRINT '--- SECTION 1: Instance-Level Settings ---';
PRINT '';

DECLARE @Config TABLE (name NVARCHAR(128), value_in_use BIGINT, [description] NVARCHAR(255));
DECLARE @CurrentValue BIGINT;

INSERT @Config EXEC sp_configure;

-- Max Degree of Parallelism
SELECT @CurrentValue = value_in_use FROM @Config WHERE name = 'max degree of parallelism';
PRINT '  Current MAXDOP: ' + CAST(ISNULL(@CurrentValue, 0) AS VARCHAR);
PRINT '  Recommendation (OLTP): ' + CAST(@CPUCount / 8 AS VARCHAR) + ' or 0 (auto)';
PRINT '  Recommendation (DW):   Higher values acceptable';
PRINT '';

-- Cost Threshold for Parallelism
SELECT @CurrentValue = value_in_use FROM @Config WHERE name = 'cost threshold for parallelism';
PRINT '  Current Cost Threshold: ' + CAST(ISNULL(@CurrentValue, 5) AS VARCHAR);
PRINT '  Recommendation (OLTP):  Consider 25-50 for heavy OLTP';
PRINT '';

-- Max Server Memory
SELECT @CurrentValue = value_in_use FROM @Config WHERE name = 'max server memory (MB)';
DECLARE @RecommendedMem INT = @TotalRAM_GB * 1024 - CASE WHEN @TotalRAM_GB <= 8 THEN 2048 WHEN @TotalRAM_GB <= 32 THEN 4096 ELSE 8192 END;
PRINT '  Current Max Server Memory (MB): ' + CAST(ISNULL(@CurrentValue, 0) AS VARCHAR);
PRINT '  Recommended Max Server Memory: ' + CAST(@RecommendedMem AS VARCHAR) + ' MB (reserve '
    + CASE WHEN @TotalRAM_GB <= 8 THEN '2 GB' WHEN @TotalRAM_GB <= 32 THEN '4 GB' ELSE '8 GB' END + ' for OS)';
PRINT '';

-- Optimize for Ad Hoc Workloads
SELECT @CurrentValue = value_in_use FROM @Config WHERE name = 'optimize for ad hoc workloads';
PRINT '  Current Optimize for Ad Hoc: ' + CASE WHEN ISNULL(@CurrentValue, 0) = 1 THEN 'Enabled' ELSE 'Disabled' END;
PRINT '  Recommendation: Enable for varied workloads';
PRINT '';

-- ============================================================================
-- SECTION 2: Database-Level Settings (Read-Only Review)
-- ============================================================================
PRINT '--- SECTION 2: Database-Level Settings ---';
PRINT '';

DECLARE @dbName SYSNAME;
DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases
WHERE database_id > 4 AND state = 0 AND is_read_only = 0
ORDER BY name;

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @dbName;

WHILE @@FETCH_STATUS = 0
BEGIN
    DECLARE @autoClose   VARCHAR(3), @autoShrink VARCHAR(3), @autoStats  VARCHAR(3), @pageVerify VARCHAR(20);
    SELECT
        @autoClose  = CASE WHEN is_auto_close_on = 1 THEN 'ON' ELSE 'OFF' END,
        @autoShrink = CASE WHEN is_auto_shrink_on = 1 THEN 'ON' ELSE 'OFF' END,
        @autoStats  = CASE WHEN is_auto_create_stats_on = 1 THEN 'ON' ELSE 'OFF' END,
        @pageVerify = page_verify_option_desc
    FROM sys.databases WHERE name = @dbName;

    IF @autoClose = 'ON' OR @autoShrink = 'ON' OR @autoStats = 'OFF'
    BEGIN
        PRINT '  ' + @dbName + ':';
        IF @autoClose = 'ON'  PRINT '    AUTO_CLOSE: ON  (recommend OFF)';
        IF @autoShrink = 'ON' PRINT '    AUTO_SHRINK: ON (recommend OFF)';
        IF @autoStats = 'OFF' PRINT '    AUTO_CREATE_STATISTICS: OFF (recommend ON)';
        PRINT '';
    END

    FETCH NEXT FROM db_cursor INTO @dbName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

-- ============================================================================
-- SECTION 3: TempDB Recommendations
-- ============================================================================
PRINT '--- SECTION 3: TempDB Recommendations ---';
PRINT '';

DECLARE @TempFiles INT, @TempSizeMB INT;
SELECT @TempFiles = COUNT(*) FROM tempdb.sys.database_files WHERE type = 0;
SELECT @TempSizeMB = CAST(SUM(size) * 8 / 1024 AS INT) FROM tempdb.sys.database_files WHERE type = 0;

PRINT '  Current TempDB data files: ' + CAST(@TempFiles AS VARCHAR);
PRINT '  Current TempDB size (MB):  ' + CAST(@TempSizeMB AS VARCHAR);
PRINT '  Recommendation: ' + CAST(CASE WHEN @CPUCount < 4 THEN 4 ELSE @CPUCount END AS VARCHAR) + ' data files (one per core, min 4)';
PRINT '  Recommendation: Equal initial size for all files to prevent allocation contention';
PRINT '';

-- ============================================================================
-- SECTION 4: Extended Events for Monitoring
-- ============================================================================
PRINT '--- SECTION 4: Extended Events (Read-Only Review) ---';
PRINT '';

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'blocking_sessions')
    PRINT '  Session "blocking_sessions" already exists.';
ELSE
    PRINT '  Session "blocking_sessions" does not exist.';
PRINT '';

-- ============================================================================
-- SECTION 5: Manual Review Items
-- ============================================================================
PRINT '--- SECTION 5: Manual Review Items ---';
PRINT '';
PRINT '  The following require manual configuration:';
PRINT '    1. Database Mail - Configure via SSMS > Management > Database Mail';
PRINT '    2. SQL Agent Alerts - Severity 016-020 alerts for security events';
PRINT '    3. Remote Admin Connections - EXEC sp_configure ''remote admin connections'', 1;';
PRINT '    4. Contained Databases - For Availability Groups, evaluate CONTAINMENT = PARTIAL';
PRINT '';

-- ============================================================================
-- SECTION 6: Summary
-- ============================================================================
PRINT REPLICATE('=', 60);
PRINT 'Review Complete';
PRINT REPLICATE('=', 60);
PRINT '';
PRINT '  This script is READ-ONLY. To apply changes, uncomment and run';
PRINT '  the relevant EXEC sp_configure statements above after reviewing.';
PRINT '  Some settings (max server memory, MAXDOP) require a restart.';
PRINT '';
PRINT '  To apply Max Server Memory (example):';
PRINT '    EXEC sp_configure ''max server memory'', ' + CAST(@RecommendedMem AS VARCHAR) + ';';
PRINT '    RECONFIGURE;';
PRINT '';
GO
