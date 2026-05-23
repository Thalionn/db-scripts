-- ============================================================================
-- Cleanup Practice Environment Script
-- Drops all objects created by practice environment setup
-- Run this before re-deploying to start fresh
-- ============================================================================

USE master;
GO
SET NOCOUNT ON;
DECLARE @StartTime DATETIME = GETDATE();
DECLARE @DroppedObjects TABLE (ObjectName NVARCHAR(256), ObjectType NVARCHAR(32));

-- ============================================================================
-- Drop PracticeDB and DBATools database
-- ============================================================================
PRINT '';
PRINT '========================================';
PRINT 'Step 1: Drop Databases';
PRINT '========================================';
PRINT '';

-- Drop PracticeDB database
IF DB_ID('PracticeDB') IS NOT NULL
BEGIN  
    PRINT '  Dropping database: PracticeDB...';
    ALTER DATABASE PracticeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PracticeDB;
    INSERT INTO @DroppedObjects (ObjectName, ObjectType) VALUES ('PracticeDB', 'DATABASE');
    PRINT '  Dropped database: PracticeDB';
END
ELSE
BEGIN  
    PRINT '  Database PracticeDB does not exist, skipping.';
END

-- Drop DBATools database if it exists and belongs to practice env
IF DB_ID('DBATools') IS NOT NULL
BEGIN  
    PRINT '  Dropping database: DBATools...';
    ALTER DATABASE DBATools SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DBATools;
    INSERT INTO @DroppedObjects (ObjectName, ObjectType) VALUES ('DBATools', 'DATABASE');
    PRINT '  Dropped database: DBATools';
END
ELSE
BEGIN  
    PRINT '  Database DBATools does not exist, skipping.';
END

PRINT '';

-- ============================================================================
-- Drop SQL Agent Jobs (Practice Environment) and DBATools Job Category 
-- ============================================================================
USE msdb;
GO
PRINT '========================================';
PRINT 'Step 2: Drop SQL Agent Jobs (Practice)';
PRINT '========================================';
PRINT '';

DECLARE @job_name NVARCHAR(128);
DECLARE job_count INT = 0;

-- Cursor to drop all practice-related jobs only (not DBATools maintenance jobs)
DECLARE job_cursor CURSOR FOR
SELECT name FROM msdb.dbo.sysjobs
WHERE name LIKE 'SalesApp_%' OR 
      name LIKE 'WarehouseApp_%' OR 
      name LIKE 'CSApp_%' OR 
      name LIKE 'ExecutiveApp_%' OR 
      name LIKE 'HRApp_%' OR 
      name LIKE 'Practice_%'
ORDER BY name;

OPEN job_cursor;
FETCH NEXT FROM job_cursor INTO @job_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @job_name)
        BEGIN
            EXEC msdb.dbo.sp_delete_job 
                @job_name = @job_name, 
                @delete_unused_schedule = 1;
            INSERT INTO @DroppedObjects (ObjectName, ObjectType) VALUES (@job_name, 'SCHEDULER');
            PRINT '  Dropped job: ''' + @job_name + '''';
        END
    END TRY
    BEGIN CATCH
    END CATCH
    FETCH NEXT FROM job_cursor INTO @job_name;
END

CLOSE job_cursor;
DEALLOCATE job_cursor

-- Drop DBATools job category (may not exist)
IF EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DBATools' AND category_class = 1)
BEGIN
    EXEC msdb.dbo.sp_delete_category @class = 'JOB', @name = 'DBATools';
    PRINT '  Dropped job category: DBATools';
END

-- Drop DatabaseMaintenance category if exists  
IF EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DatabaseMaintenance' AND category_class = 1)
BEGIN
    EXEC msdb.dbo.sp_delete_category @class = 'JOB', @name = 'DatabaseMaintenance';
    PRINT '  Dropped job category: DatabaseMaintenance';
END

PRINT '';

-- ============================================================================
-- Drop Schedules (Practice Environment Only)
-- ============================================================================
PRINT '========================================';  
PRINT 'Step 3: Drop Schedules (Practice Env)';
PRINT '========================================';
PRINT '';

DECLARE @schedule_id INT;
DECLARE @schedule_name NVARCHAR(128);
DECLARE @schedules_dropped INT = 0;

-- Only drop practice-related schedules
DECLARE schedule_cursor CURSOR FOR
SELECT schedule_id, name FROM msdb.dbo.sysschedules
WHERE (name LIKE 'Practice%' OR 
      name LIKE 'SalesApp%' OR 
      name LIKE 'WarehouseApp%' OR 
      name LIKE 'CSApp%' OR 
      name LIKE 'ExecutiveApp%' OR  
      name LIKE 'HRApp%')
ORDER BY name;

OPEN schedule_cursor;
FETCH NEXT FROM schedule_cursor INTO @schedule_id, @schedule_name;

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN TRY
        EXEC msdb.dbo.sp_delete_schedule @schedule_id = @schedule_id;
        PRINT '  Dropped schedule: ''' + @schedule_name + '''';
        SET @schedules_dropped = @schedules_dropped + 1;
    END TRY
    BEGIN CATCH
    END CATCH
    FETCH NEXT FROM schedule_cursor INTO @schedule_id, @schedule_name;
END

CLOSE schedule_cursor;
DEALLOCATE schedule_cursor

IF @schedules_dropped = 0
    PRINT '  No practice schedules found to drop.';
    
PRINT '';

-- ============================================================================
-- Drop Server-Level Trigger
-- ============================================================================
USE master;
GO
PRINT '========================================';  
PRINT 'Step 4: Drop Logins and Triggers';
PRINT '========================================';
PRINT '';

IF OBJECT_ID('trg_LoginAudit', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER trg_LoginAudit ON ALL SERVER;
    PRINT '  Dropped trigger: trg_LoginAudit';
END
    
-- If it exists with different quoting, try that version  
IF (OBJECT_ID('trg_LoginAudit', 'TR') IS NULL) AND OBJECT_ID('[trg_LoginAudit]', 'TR') IS NOT NULL
BEGIN
    DROP TRIGGER [trg_LoginAudit] ON ALL SERVER;
    PRINT '  Dropped trigger: trg_LoginAudit';
END

PRINT '';

-- ============================================================================  
-- Drop Server-Level Logins (Practice Environment)
-- ============================================================================
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SalesAppLogin')
BEGIN
    DROP LOGIN [SalesAppLogin];
    PRINT '  Dropped login: SalesAppLogin';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'WarehouseAppLogin')
BEGIN
    DROP LOGIN [WarehouseAppLogin];
    PRINT '  Dropped login: WarehouseAppLogin';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'AnalyticsAppLogin')  
BEGIN
    DROP LOGIN [AnalyticsAppLogin];
    PRINT '  Dropped login: AnalyticsAppLogin';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'HRAppLogin')
BEGIN
    DROP LOGIN [HRAppLogin];
    PRINT '  Dropped login: HRAppLogin';
END
    
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'CSAppLogin')  
BEGIN
    DROP LOGIN [CSAppLogin];
    PRINT '  Dropped login: CSAppLogin';
END

IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ExecutiveAppLogin')
BEGIN  
    DROP LOGIN [ExecutiveAppLogin];
    PRINT '  Dropped login: ExecutiveAppLogin';
END

PRINT '';

-- ============================================================================
-- Drop First Responder Kit Procedures (if they exist in master and were deployed)
-- ============================================================================
USE master;  
GO
PRINT '========================================';
PRINT 'Step 5: Drop FRK Procedures (Optional/If Deployed)';
PRINT '========================================';
PRINT '';

DECLARE @proc_name NVARCHAR(128);
DECLARE @proc_count INT = 0;

DECLARE proc_cursor CURSOR FOR
SELECT DISTINCT sp.name
FROM sys.procedures sp
WHERE sp.name IN ('sp_Blitz', 'sp_BlitzFirst', 'sp_BlitzIndex', 
                  'sp_BlitzCache')
    AND (sp.schema_id = SCHEMA_ID('dbo') OR sp.name LIKE 'sp_Blitz%');

OPEN proc_cursor;
FETCH NEXT FROM proc_cursor INTO @proc_name;

WHILE @@FETCH_STATUS = 0
BEGIN  
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM sys.procedures WHERE name = @proc_name AND schema_id = SCHEMA_ID('dbo'))
        BEGIN
            DECLARE @drop_sql NVARCHAR(256) = 'DROP PROCEDURE dbo.' + @proc_name;
            EXEC(@drop_sql);
            PRINT '  Dropped procedure: ''' + @proc_name + '''';
            SET @proc_count = @proc_count + 1;
        END
    END TRY  
    BEGIN CATCH
    END CATCH
    FETCH NEXT FROM proc_cursor INTO @proc_name;
END

CLOSE proc_cursor;
DEALLOCATE proc_cursor

IF @proc_count = 0
    PRINT '  No FRK procedures found to drop.';

PRINT '';
PRINT '========================================';  
PRINT 'Cleanup complete!';
PRINT '========================================';
