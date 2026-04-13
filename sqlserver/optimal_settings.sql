-- ============================================================================
-- Script: optimal_settings.sql
-- Purpose: Apply SQL Server best practice settings
-- Usage:   Review and run in stages, test first!
-- Notes:   Some settings require restart. Run sections separately.
-- ============================================================================

SET NOCOUNT ON;

PRINT '============================================================';
PRINT 'SQL Server Optimal Configuration Script';
PRINT 'Based on community best practices';
PRINT '============================================================';
PRINT '';

------------------------------------------------------------
-- SECTION 1: INSTANCE-LEVEL SETTINGS (Requires Restart)
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 1: Instance-Level Settings ---';
PRINT '--- Requires restart after execution ---';
PRINT '';

PRINT '
-- Run these manually if needed (requires restart):

-- 1. Max Degree of Parallelism (DOP)
-- Rule of thumb: 0 for 8 or fewer cores, or (cores / 8) 
EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''max degree of parallelism'', 4;  -- Adjust to your CPU count
RECONFIGURE;

-- 2. Cost Threshold for Parallelism
-- Increase from default 5 if OLTP workload
EXEC sp_configure ''cost threshold for parallelism'', 50;
RECONFIGURE;

-- 3. Max Server Memory (MB)
-- Reserve 4GB for OS + 1GB per 32GB of RAM
EXEC sp_configure ''max server memory'', 24576;  -- Adjust to your RAM
RECONFIGURE;
';

------------------------------------------------------------
-- SECTION 2: DATABASE-LEVEL SETTINGS
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 2: Database-Level Settings ---';
PRINT '';

DECLARE @SQL NVARCHAR(MAX);

SELECT @SQL = STRING_AGG(CAST('
-- ' + name + '
ALTER DATABASE [' + name + '] SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [' + name + '] SET AUTO_SHRINK OFF WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [' + name + '] SET AUTO_CREATE_STATISTICS ON WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH ROLLBACK IMMEDIATE;
ALTER DATABASE [' + name + '] SET RECOVERY ' + 
    CASE WHEN recovery_model_desc = 'FULL' THEN 'FULL' ELSE 'SIMPLE' END + ';
' AS NVARCHAR(MAX)), CHAR(13))
FROM sys.databases
WHERE name NOT IN ('tempdb', 'model')
  AND state_desc = 'ONLINE';

EXEC sp_executesql @SQL;

PRINT 'Applied AUTO_CLOSE, AUTO_SHRINK, STATISTICS, RECOVERY to user databases.';
PRINT '';

------------------------------------------------------------
-- SECTION 3: TEMPDB OPTIMIZATION
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 3: TempDB Optimization ---';
PRINT '';

SELECT 
    'USE [tempdb];' + CHAR(13) + CHAR(10) +
    'ALTER DATABASE [tempdb] MODIFY FILE (NAME = ''' + mf.name + ''', SIZE = ' + 
        CAST(CASE WHEN mf.size * 8 / 1024 < 1024 THEN 1024 ELSE mf.size * 8 / 1024 END AS VARCHAR) + 'MB);' AS OptimizedFileSetup
FROM sys.master_files mf
WHERE mf.database_id = DB_ID('tempdb')
  AND mf.type = 0;

PRINT '';
PRINT 'TempDB Best Practices:';
PRINT '1. Create multiple data files (1 per 4 cores, max 8)';
PRINT '2. Each file same initial size';
PRINT '3. Enable TF1118 (if pre-2016)';
PRINT '4. Use trace flag 1118 for dedicated tempdb';
PRINT '';

------------------------------------------------------------
-- SECTION 4: QUERY STORE (SQL 2016+)
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 4: Query Store Configuration ---';
PRINT '';

DECLARE @DBName NVARCHAR(128);
DECLARE db_cursor CURSOR FOR
SELECT name FROM sys.databases 
WHERE state_desc = 'ONLINE' 
  AND name NOT IN ('master', 'tempdb', 'model', 'msdb');

OPEN db_cursor;
FETCH NEXT FROM db_cursor INTO @DBName;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @SQL = N'
    ALTER DATABASE [' + @DBName + '] SET QUERY_STORE = ON;
    ALTER DATABASE [' + @DBName + '] SET QUERY_STORE (OPERATION_MODE = READ_WRITE, 
        CLEANUP_POLICY = (STALE_QUERY_THRESHOLD_DAYS = 30),
        DATA_FLUSH_INTERVAL_SECONDS = 60,
        MAX_STORAGE_SIZE_MB = 100,
        INTERVAL_LENGTH_MINUTES = 10);';
    
    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Query Store enabled on: ' + @DBName;
    END TRY
    BEGIN CATCH
        PRINT 'Skipped ' + @DBName + ': ' + ERROR_MESSAGE();
    END CATCH
    
    FETCH NEXT FROM db_cursor INTO @DBName;
END

CLOSE db_cursor;
DEALLOCATE db_cursor;

------------------------------------------------------------
-- SECTION 5: INCLUDE KILL SP FOR BLOCKING
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 5: Extended Events for Blocking ---';
PRINT '';

PRINT '
-- Create extended event session for blocking
IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = ''BlockedRequests'')
    DROP EVENT SESSION BlockedRequests ON SERVER;
GO

CREATE EVENT SESSION BlockedRequests ON SERVER
ADD EVENT sqlserver.xml_deadlock_report
ADD TARGET package0.event_file(SET filename = ''BlockedRequests'', max_file_size = 100)
WITH (MAX_DISPATCH_LATENCY = 30 SECONDS);
GO

ALTER EVENT SESSION BlockedRequests ON SERVER STATE = START;
GO
';

------------------------------------------------------------
-- SECTION 6: OPTIONAL: ENABLE LOCK PAGES IN MEMORY (Windows only)
------------------------------------------------------------
PRINT '';
PRINT '--- SECTION 6: Lock Pages in Memory (Windows Only) ---';
PRINT '';
PRINT 'To enable Lock Pages in Memory:';
PRINT '1. Open Local Security Policy (secpol.msc)';
PRINT '2. Navigate to: Local Policies > User Rights Assignment';
PRINT '3. Add user running SQL Server to "Lock pages in memory"';
PRINT '4. Restart SQL Server';
PRINT '';
PRINT 'Then run:';
PRINT 'EXEC sp_configure ''show advanced options'', 1;';
PRINT 'RECONFIGURE;';
PRINT 'EXEC sp_configure ''lpim'', 1;';
PRINT 'RECONFIGURE;';

------------------------------------------------------------
-- SECTION 7: SETTINGS TO REVIEW MANUALLY
------------------------------------------------------------
PRINT '';
PRINT '============================================================';
PRINT 'REVIEW MANUALLY:';
PRINT '============================================================';
PRINT '';
PRINT '1. Database Mail (for alerts):';
PRINT '   Configure via SSMS > Management > Database Mail';
PRINT '';
PRINT '2. SQL Server Agent Alerts:';
PRINT '   Add alerts for severity 016, 017, 018, 019, 020';
PRINT '   Add alert for 823, 824, 825 (data corruption)';
PRINT '';
PRINT '3. Optimize for ad-hoc workloads:';
PRINT '   EXEC sp_configure ''optimize for ad hoc workloads'', 1;';
PRINT '';
PRINT '4. Remote admin connections:';
PRINT '   EXEC sp_configure ''remote admin connections'', 1;';
PRINT '';
PRINT '5. Contained Databases (if using AGs):';
PRINT '   ALTER DATABASE [YourDB] SET CONTAINMENT = PARTIAL;';
PRINT '';
PRINT '============================================================';
PRINT 'Configuration script complete';
PRINT '============================================================';
