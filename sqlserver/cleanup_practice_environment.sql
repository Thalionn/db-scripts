-- ============================================================================
-- Cleanup Practice Environment Script
-- Drops all objects created by 20B_deploy_practice_env_job.sql
-- Run this before re-deploying to start fresh
-- ============================================================================

USE master;
GO

-- ============================================================================
-- Drop PracticeDB database
-- ============================================================================
IF DB_ID('PracticeDB') IS NOT NULL
BEGIN
    ALTER DATABASE PracticeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PracticeDB;
    PRINT 'Dropped database: PracticeDB';
END
ELSE
BEGIN
    PRINT 'Database PracticeDB does not exist, skipping...';
END
GO

-- ============================================================================
-- Drop DBATools database
-- ============================================================================
IF DB_ID('DBATools') IS NOT NULL
BEGIN
    ALTER DATABASE DBATools SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DBATools;
    PRINT 'Dropped database: DBATools';
END
ELSE
BEGIN
    PRINT 'Database DBATools does not exist, skipping...';
END
GO

-- ============================================================================
-- Drop SQL Agent Jobs (Practice Environment)
-- ============================================================================
USE msdb;
GO

DECLARE @job_name NVARCHAR(128);

-- Cursor to drop all practice-related jobs
DECLARE job_cursor CURSOR FOR
SELECT name FROM msdb.dbo.sysjobs
WHERE name LIKE 'SalesApp_%'
   OR name LIKE 'WarehouseApp_%'
   OR name LIKE 'CSApp_%'
   OR name LIKE 'ExecutiveApp_%'
   OR name LIKE 'HRApp_%'
   OR name LIKE 'Practice_%'
   OR name LIKE 'DBATools - %'
   OR name LIKE 'DatabaseBackup - %'
   OR name LIKE 'DatabaseIntegrityCheck - %';

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_delete_job @job_name = @job_name, @delete_unused_schedule = 1;
    PRINT 'Dropped job: ' + @job_name;
    FETCH NEXT FROM job_cursor INTO @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor;
GO

-- ============================================================================
-- Drop Schedules (DBATools)
-- ============================================================================
DECLARE @schedule_id INT;
DECLARE @schedule_name NVARCHAR(128);

DECLARE schedule_cursor CURSOR FOR
SELECT schedule_id, name FROM msdb.dbo.sysschedules
WHERE name LIKE 'Every%_WaitStats'
   OR name LIKE 'Every%_PerfCounters'
   OR name LIKE 'Hourly_DatabaseSizes'
   OR name LIKE 'DailyMidnight_PurgeOldData'
   OR name LIKE 'Every%_QueryStats'
   OR name LIKE 'Daily8AM'
   OR name LIKE 'Every5Minutes'
   OR name LIKE 'Every1Minute'
   OR name LIKE 'Every15Minutes'
   OR name LIKE 'DailyFullBackup'
   OR name LIKE 'LogBackupEvery15Min'
   OR name LIKE 'WeeklyIntegrityCheck'
   OR name LIKE 'Sunday2AM'
   OR name = 'DailyMidnight_PurgeOldData'
   OR name = 'Every5Minutes_WaitStats'
   OR name = 'Every5Minutes_PerfCounters'
   OR name = 'Hourly_DatabaseSizes'
   OR name = 'DailyMidnight_PurgeOldData'
   OR name = 'Every30Minutes_QueryStats';

OPEN schedule_cursor;
FETCH NEXT FROM schedule_cursor INTO @schedule_id, @schedule_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC msdb.dbo.sp_delete_schedule @schedule_id = @schedule_id;
    PRINT 'Dropped schedule: ' + @schedule_name;
    FETCH NEXT FROM schedule_cursor INTO @schedule_id, @schedule_name;
END

CLOSE schedule_cursor;
DEALLOCATE schedule_cursor;
GO

-- ============================================================================
-- Drop Server-Level Trigger
-- ============================================================================
USE master;
GO

IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'trg_LoginAudit')
BEGIN
    DROP TRIGGER trg_LoginAudit ON ALL SERVER;
    PRINT 'Dropped server trigger: trg_LoginAudit';
END
ELSE
BEGIN
    PRINT 'Server trigger trg_LoginAudit does not exist, skipping...';
END
GO

-- ============================================================================
-- Drop Server-Level Logins
-- ============================================================================
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SalesAppLogin')
BEGIN
    DROP LOGIN [SalesAppLogin];
    PRINT 'Dropped login: SalesAppLogin';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'WarehouseAppLogin')
BEGIN
    DROP LOGIN [WarehouseAppLogin];
    PRINT 'Dropped login: WarehouseAppLogin';
END
GO

-- ============================================================================
-- Drop Categories (MSDB)
-- ============================================================================
USE msdb;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DBATools' AND category_class = 1)
BEGIN
    EXEC msdb.dbo.sp_delete_category @class = 'JOB', @name = 'DBATools';
    PRINT 'Dropped category: DBATools';
END

IF EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DatabaseMaintenance' AND category_class = 1)
BEGIN
    EXEC msdb.dbo.sp_delete_category @class = 'JOB', @name = 'DatabaseMaintenance';
    PRINT 'Dropped category: DatabaseMaintenance';
END
GO

-- ============================================================================
-- Drop First Responder Kit Procedures (if exist in master)
-- ============================================================================
USE master;
GO

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_Blitz' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP PROCEDURE dbo.sp_Blitz;
    PRINT 'Dropped procedure: sp_Blitz';
END

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_BlitzFirst' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP PROCEDURE dbo.sp_BlitzFirst;
    PRINT 'Dropped procedure: sp_BlitzFirst';
END

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_BlitzIndex' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP PROCEDURE dbo.sp_BlitzIndex;
    PRINT 'Dropped procedure: sp_BlitzIndex';
END

IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'sp_BlitzCache' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    DROP PROCEDURE dbo.sp_BlitzCache;
    PRINT 'Dropped procedure: sp_BlitzCache';
END
GO

PRINT '========================================';
PRINT 'Cleanup complete!';
PRINT '========================================';
GO
