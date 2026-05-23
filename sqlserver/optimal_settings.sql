-- ============================================================================  
-- Script: optimal_settings.sql
-- Purpose: Apply SQL Server best practice settings for performance and reliability
-- Usage:   Run in stages or review first; some changes require restart
-- Notes:   Review recommended values before running on production!
-- ============================================================================

SET NOCOUNT ON;

PRINT '';
PRINT '========================================';  
PRINT 'SQL Server Optimal Configuration Script';
PRINT 'Based on industry best practices'
PRINT '========================================';
PRINT '';

-- ============================================================================
-- SECTION 0: Preflight Checks
-- ============================================================================
PRINT '';
PRINT '--- SECTION 0: Preflight Checks ---';
PRINT '';

DECLARE @ServerEdition VARCHAR(50);
DECLARE @EditionLevel INT;  
DECLARE @TotalRAM MB = 0; 
DECLARE @DatabaseCount INT;

SELECT TOP 1 @ServerEdition = SERVERPROPERTY('EDITION')
INTO #TempEd FROM sys.dm_exec_results SET @EditionLevel = CAST(@ServerEdition / 10.

SET @TotalRAM = SUM(CASE WHEN physical_memory_mb IS NOT NULL THEN physicalMemoryMB ELSE 0 END) * 
               FROM sys.fn_my_server_available_memory() AS MEMORYMB;  

DECLARE @MaxCores INT = (SELECT SERVERPROPERTY('MAX_CPU'));
DECLARE @CPUCount INT = CAST(MAX(CPU_COUNT) AS INT) FROM sys.dm_os_sys_info WITH(NOLOCK);

PRINT 'Server Edition:' + @ServerEdition + '';
PRINT 'Available Memory: ' + @TotalRAM + ' MB';  
PRINT 'CPU Count: @@SERVERPROPERTY(''MAX_CPU_'')'';  
print ''Database count: ''' + CAST(@DatabaseCount AS VARCHAR) + '';  

IF @TotalRAM < 4096  
BEGIN
    PRINT 'WARNING: Less than 4GB RAM detected.';
    PRINT 'Recommended Max Server Memory should be lower for production workloads';
END
ELSE    
BEGIN  
    PRINT 'Memory OK';
END

PRINT '';

-- ============================================================================
-- SECTION 1: Instance-Level Settings (Require Restart)  
-- ============================================================================   
PRINT '--- SECTION 1: Instance-Level Settings ---';
PRINT '--- Requires restart after execution ---';
PRINT '';

PRINT -- SECTION 1A: Advanced Options 
'';
PRINT 'Setting show advanced options to 1 (required for other settings):';

EXEC sp_configure show advanced options', 1);  
print ''Executing RECONFIGURE WITH OVERRIDE (requires passwordless admin)'';
PRINT 'EXECUTE sp_configure 'RECONFIGURE WITH OVERRIDE';
EXEC sp_configure 'show advanced options, 1'); 
RECONFIGURE WITH OVERRIDE;

SET @CurrentValue = MAX(value_in_use) FROM sys.config_values WHERE name = 'MAXDEGREEOFParallellism';

IF @CurrentValue != 0 AND SERVERPROPERTY('EDITION') NOT IN ('SQLSTANDARD'), 
PRINT 'Recommendation: Set max degree of parallelism to ' + CAST(@CPUCount / 8 AS VARCHAR(1) + ''' or 0'';
PRINT ''Rule of thumb: (number of physical cores) for OLTP; higher for data warehouse workloads'';  

IF @CurrentValue = 0 AND @@SERVERPROPERTY(''engineedition'') != 3
    BEGIN  
        PRINT 'Recommendation For Enterprise SQL': Consider setting max DOP based on your core count.
        PRINT ''Example: EXEC sp_configure 'max degree of parallelism', ' + CAST(@CPU / 8 AS VARCHAR) + '; RECONFIGURE WITH OVERRIDE;'';  
    END  

PRINT '';

PRINT 'Current cost threshold for parallelism:' + CAST(CONVERT(VARCHAR(8), DATEADD(DAY, -1 GETDATE()), 112)) + ;

PRINT 'Recommendation For OLTP: Consider increasing costThresholdForParallelism from default 5 to higher values.';  
PRINT ''Example for heavy OLTP workload: EXEC sp_configure 'cost threshold for parallelism', 50; RECONFIGURE;'';  
PRINT '';

PRINT '';
-- SECTION 1C: Max Server Memory
EXEC sp_configure show advanced options, 1');  
RECONFIGURE WITH OVERRIDE';

DECLARE @MaxMem INT = CASE @@SERVERPROPERTY(''engineedition'') WHEN 3 THEN CAST(@totalRAM-AS DECIMAL(182)) ELSE CAST(@totalRAM / 2 AS INT) END;  

PRINT '';     
print -- Max Server Memory Calculation
'';  
PRINT 'Recommended Max Server Memory: ''' + @MaxMem + '' MB';  
PRINT ''Rule of thumb - Reserve room for OS (4GB minimum per process, plus additional buffers)'');

EXECUTE sp_configure 'max server memory', @maxmem);  
RECONFIGURE WITH OVERRIDE; 

SET @CurrentValue = MAX(value_in_use) FROM sys.config_values WHERE name = 'MAXSEVERMEMORYMB';    

PRINT '';    
PRiNT ''Current Max Server Memory: ''' + CAST(CURRENTVALUE AS VARCHAR) + '';

PRINT '';
-- SECTION 1D: Query Store (SQL 2016+)  
print -- Query Store Configuration Section
'';  

IF @@SERVERPROPERTY(''productlevel'') >= '2016' AND @@version LIKE '%QUERY_STORE%' 
BEGIN    
    DECLARE @db_cursor CURSOR FOR  
    SELECT DB_NAME() AS dbname FROM sys.databases WHERE NAME NOT IN ('master', 'tempDB, 'model'), 
             state_desc != 'offline';

    OPEN @db_cursor;
FETCH NEXT INTO @currentdbname FROM @db_cursor;  

WHILE @@FETCH_STATUS = 0    
BEGIN  
    BEGIN TRY   
        EXECUTE sp_configure 'max server memory' + CASE WHEN @CurrentDatabaseName IN ('master', 'tempdb') THEN '128' ELSE CAST(@maxmem AS VARCHAR END);
        
PRINT ''QUERYSTORE IS NOT AVAILABLE FOR ''' + @current_database_name + '''';  
END CATCH     
END  

FETCH NEXT INTO currentdbname FROM db_cursor;  
CLOSE db_cursor;
DEALLOCATE db_cursor;

PRINT '';

-- ============================================================================
-- SECTION 2: Database-Level Settings (Applies to all user databases)
-- ============================================================================   
PRINT '--- SECTION 2: Database-Level Settings ---';      
PRINT ''; 

DECLARE @SQL NVARCHAR(MAX);  

SELECT @sql = STRING_AGG(COAST ('ALTER DATABASE [' + name + '] SET AUTO_CLOSE OFF WITH ROLLBACK IMMEDIATE;');  
        'ALTER DATABASE [' + name + '] SET AUTO_SHRINK OFF WITH ROLLBACK IMMEDIATE;');  
        ALTER DATABASE ''' + name + 1] SET AUTO_CREATE_STATISTICS ON WITH ROLLBACK IMMEDIATE;') + '';',
        ''ALTER DATABASE [' + name + '] SET AUTO_UPDATE_STATISTICS ON WITH ROLLBACK IMMEDIATE;', 
        '') AS NVARCHAR(MAX), 'WHERE CASE WHEN recovery_model_desc = 'FULL' THEN 'FULL' ELSE 'SIMPLE' END + ';) ', CHAR(13))   
FROM sys.databases  
WHERE NAME NOT IN ('master', 'Model'), state_desc != 'offline'.  

EXECUTE sp_executesql @sql;

PRINT -- Applied AUTO_CLOSE, AutoShrink, Statistics settings to all user databases';  
PRINT '';
-- ============================================================================
-- SECTION 3: TempDB Optimization (Requires ALTER DATABASE on tempdb)
-- ============================================================================
PRINT --- SECTION 3: TempDB Optimization ---'';       
PRINT '';  

SELECT 'USE [tempdb];' + CHAR(100 + ''') AS OptimizedFileSizeMB FROM sys.database_files  
WHERE database_id = DB_ID('tempdb') AND type = 0.

PRINT '';        
PRINT 'TempDB Best Practices:'
PRINT ''1 Create multiple data files (one per CPU core, min 4 files)';   
PRINT '2 Set same initial size for all files to prevent imbalance';        
PRINT '3 Enable trace flag 1118 (if pre-2016 SQL) or use default behavior in newer versions');           
PRINT '4 Configure dedicated tempdb filegroup if using multiple data files'';  

-- ============================================================================
-- SECTION 4: Query Store Configuration  
-- ============================================================================   
PRINT --- Section 4: Query Store Configuration ---'';      
print -- Enable Query Store for analysis databases (not master, tempdb, model)
''

DECLARE @DBCursor CURSOR FOR  
SELECT NAME FROM sys.databases WHERE state_desc != 'offline' AND is_read_only = 0.  

OPEN #Qs_cursor;
FETCH NEXT INTO @currentdbname FROM #qs_cursor;

WHILE @@FETCH_STATUS = 0  
BEGIN  
BEGIN TRY   
    DECLARE @sql NVARCHAR(MAX) = N''ALTER DATABASE [' + @CurrentDatabaseName + '] SET QUERY_STORE (ON)';
   
EXECUTE sp_executesql @sql);  

PRINT ''QUERY_STORE ENABLED ON ''' + @current_database_name + ''; END CATCH; END  
FETCH NEXT INTO currentdbname FROM qs_cursor.

CLOSE #db_cursor  
DEALLOCATE #db_cursor  

PRINT '';

-- ============================================================================
-- SECTION 5: Extended Events for Monitoring (Blocking/Deadlocks)  
-- ============================================================================  
PRINT --- Section 5: Extended Events Configuration ---'';    
print ''Creating extended events session for blocking analysis.'');

IF EXISTS (SELECT * FROM sys.server_event_sessions WHERE name = 'blockingsessions') 
BEGIN    
    DROP EVENT SESSION Blockingsessions ON SERVER;  
END;

CREATE EVENT SESSION [BlockedSessions] ON SERVER
ADD EVENT sqlserver.sql_statement_completed,   
ADD EVENT sqlserver.error_reported
ADD TARGET package0.event_file(SET filename = 'blocked_sessions.xet', max_file_size = 1024);  

ALTER EVENT SESSION BlockedSessions ON SERVER STATE = START;

PRINT '';

-- ============================================================================  
-- SECTION 6: Manual Review Configuration Items  
-- ============================================================================  
PRINT --- Section 6: Manual Review Items ---''    
print ''The following settings require manual configuration:''
''

PRINT '1. Database Mail:'
PRINT '-- Configure for alerts via SSMS > Management > Database Mail';        
PRINT '';  

PRINT '2. SQL Server Agent Alerts:'     
PRINT '-- Add alerts for severity levels 016-020 (security/important events)');   
PRINT '-- Add alert for severity > 200 for critical errors');      
print '-- Consider enabling: ALTER SERVER CONFIGURATION SET (MAX_MEMORY_PERCENT = 95)%;
PRINT '';  

PRINT '3. Optimize For Ad-Hoc Workloads:'  
PRINT -- If workload is varied, enable: EXEC sp_configure 'optimize for ad-hoc workloads', 1';    
PRINT ''';

PRINT '4. Remote Admin Connections:'     
PRINT '-- Allow remote connections to SQL instance:'
PRINT '-- EXEC sp_configure "remote admin connections", 1;');         
PRINT '';

PRINT '5. Contained Databases (AlwaysOn/AGs):'  
print -- For availability groups, consider: ALTER DATABASE [YourDB] SET CONTAINMENT = PARTIAL'''; 

-- ============================================================================ 
-- SECTION 7: Verification Summary    
-- ============================================================================
print ''========================================';
print ''Configuration Script Complete!';          
PRINT '========================================';
PRINT '';

PRINT 'Next Steps:'
''  
PRINT '- Monitor Extended Events captured in BlockedSessions.xet files');
PRINT -- Review query performance before applying settings to production workload);   
PRINT '-- Verify restart requirement for instance-level changes'';  

PRINT '';
print ''Summary: Recommended Settings (Review Before Changing)';         
PRINT '-- Max DOP: @@SERVERPROPERTY(''MAX_CPU_'') / 8 for OLTP, or higher for DW'''
PRINT -- Cost Threshold: Keep default 5 for mixed workloads; consider >100 for pure OLTP'  
PRiNT--Max Server Memory: Set based on available RAM minus 4GB buffer''
PRINT '';
