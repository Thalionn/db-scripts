-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
--          https://ola.hallengren.com
-- ============================================================================

USE master;
GO

-- Create DatabaseMaintenance category if it doesn't exist (fixes missing category error)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DatabaseMaintenance' AND category_class = 1)
BEGIN
    EXEC msdb.dbo.sp_add_category
        @class = 'JOB',
        @type = 'LOCAL',
        @name = 'DatabaseMaintenance';
END
GO

-- ============================================================================
-- DatabaseBackup - Full backups for all databases (daily at 10 PM)
-- ============================================================================
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DatabaseBackup - FULL - All Databases')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DatabaseBackup - FULL - All Databases', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DatabaseBackup - FULL - All Databases',
    @description = 'Performs full backups of all databases using Ola Hallengren script',
    @category_name = 'DatabaseMaintenance',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DatabaseBackup - FULL - All Databases',
    @step_name = 'Execute Backup',
    @subsystem = 'TSQL',
    @command = '
DECLARE @BackupDirectory NVARCHAR(500) = ''D:\SQLBackups''
EXECUTE [dbo].[DatabaseBackup]
    @Databases = ''ALL_DATABASES'',
    @Directory = @BackupDirectory,
    @BackupType = ''F'',
    @Verify = ''Y'',
    @CleanupTime = 168,
    @CheckSum = ''Y'',
    @LogToTable = ''Y'',
    @Execute = ''Y'';
',
    @database_name = 'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create DailyFullBackup schedule (daily at 10 PM, fixed invalid @freq_hour parameter)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'DailyFullBackup')
BEGIN
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = 'DailyFullBackup',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 1,
        @freq_subday_interval = 0,
        @active_start_time = 220000;
END
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DatabaseBackup - FULL - All Databases',
    @schedule_name = 'DailyFullBackup';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DatabaseBackup - FULL - All Databases',
    @server_name = @@SERVERNAME;
GO

-- ============================================================================
-- DatabaseBackup - Log backups for FULL recovery databases (every 15 min)
-- ============================================================================
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DatabaseBackup - LOG - All Databases')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DatabaseBackup - LOG - All Databases', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DatabaseBackup - LOG - All Databases',
    @description = 'Performs transaction log backups for full recovery databases',
    @category_name = 'DatabaseMaintenance',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DatabaseBackup - LOG - All Databases',
    @step_name = 'Execute Backup',
    @subsystem = 'TSQL',
    @command = '
DECLARE @BackupDirectory NVARCHAR(500) = ''D:\SQLBackups''
EXECUTE [dbo].[DatabaseBackup]
    @Databases = ''USER_DATABASES'',
    @Directory = @BackupDirectory,
    @BackupType = ''L'',
    @Verify = ''Y'',
    @CleanupTime = 72,
    @CheckSum = ''Y'',
    @LogToTable = ''Y'',
    @Execute = ''Y'';
',
    @database_name = 'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create LogBackupEvery15Min schedule (every 15 minutes)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'LogBackupEvery15Min')
BEGIN
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = 'LogBackupEvery15Min',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 4,
        @freq_subday_interval = 15;
END
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DatabaseBackup - LOG - All Databases',
    @schedule_name = 'LogBackupEvery15Min';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DatabaseBackup - LOG - All Databases',
    @server_name = @@SERVERNAME;
GO

-- ============================================================================
-- DatabaseIntegrityCheck - Weekly (Sundays)
-- ============================================================================
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DatabaseIntegrityCheck - ALL_DATABASES')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DatabaseIntegrityCheck - ALL_DATABASES', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DatabaseIntegrityCheck - ALL_DATABASES',
    @description = 'Performs integrity checks on all databases',
    @category_name = 'DatabaseMaintenance',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DatabaseIntegrityCheck - ALL_DATABASES',
    @step_name = 'Execute Integrity Check',
    @subsystem = 'TSQL',
    @command = '
EXECUTE [dbo].[DatabaseIntegrityCheck]
    @Databases = ''ALL_DATABASES'',
    @CheckCommands = ''CHECKDB'',
    @PhysicalOnly = ''N'',
    @NoIndex = ''N'',
    @ExtendedLogicalChecks = ''Y'',
    @LogToTable = ''Y'';
',
    @database_name = 'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Create WeeklyIntegrityCheck schedule (fixed duplicate @freq_type parameter)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'WeeklyIntegrityCheck')
BEGIN
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = 'WeeklyIntegrityCheck',
        @freq_type = 8,
        @freq_interval = 64,
        @freq_recurrence_factor = 1;
END
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DatabaseIntegrityCheck - ALL_DATABASES',
    @schedule_name = 'WeeklyIntegrityCheck';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DatabaseIntegrityCheck - ALL_DATABASES',
    @server_name = @@SERVERNAME;
GO

PRINT 'Ola Hallengren backup jobs template created.';
PRINT 'Note: Requires Ola Hallengren MaintenanceSolution to be installed first.';
PRINT 'Download from: https://ola.hallengren.com';
GO
