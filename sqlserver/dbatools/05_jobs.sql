-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE msdb;
GO

/* ====================================================== */
-- Job: DBATools - Capture Wait Stats (every 15 minutes)
/* ====================================================== */

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Capture Wait Stats')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Capture Wait Stats', @delete_unused_schedule = 1;
GO

-- Check that procedure exists before adding job step
IF OBJECT_ID(N'[DBATools].[dba].[CaptureWaitStats]') IS NULL
BEGIN
    RAISERROR('Procedure DBATools.dba.CaptureWaitStats does not exist. Please create it first.', 16, 1);
    RETURN;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Capture Wait Stats',
    @description = 'Collects wait statistics every 15 minutes',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Capture Wait Stats',
    @step_name = 'Capture Wait Stats',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureWaitStats;',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Every 15 minutes
IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'Every15Minutes_WaitStats')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = 'Every15Minutes_WaitStats';
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every15Minutes_WaitStats',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 15;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Capture Wait Stats',
    @schedule_name = 'Every15Minutes_WaitStats';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Capture Wait Stats',
    @server_name = @@SERVERNAME;
GO

/* ====================================================== */
-- Job: DBATools - Capture Perf Counters (every 5 minutes)
/* ====================================================== */

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Capture Performance Counters')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Capture Performance Counters', @delete_unused_schedule = 1;
GO

-- Check that procedure exists before adding job step
IF OBJECT_ID(N'[DBATools].[dba].[CapturePerfCounters]') IS NULL
BEGIN
    RAISERROR('Procedure DBATools.dba.CapturePerfCounters does not exist. Please create it first.', 16, 1);
    RETURN;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Capture Performance Counters',
    @description = 'Collects performance counter metrics every 5 minutes',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Capture Performance Counters',
    @step_name = 'Capture Perf Counters',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CapturePerfCounters;',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Every 5 minutes
IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'Every5Minutes_PerfCounters')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = 'Every5Minutes_PerfCounters';
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every5Minutes_PerfCounters',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 5;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Capture Performance Counters',
    @schedule_name = 'Every5Minutes_PerfCounters';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Capture Performance Counters',
    @server_name = @@SERVERNAME;
GO

/* ====================================================== */
-- Job: DBATools - Capture Database Sizes (every hour)
/* ====================================================== */

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Capture Database Sizes')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Capture Database Sizes', @delete_unused_schedule = 1;
GO

-- Check that procedure exists before adding job step
IF OBJECT_ID(N'[DBATools].[dba].[CaptureDatabaseSizes]') IS NULL
BEGIN
    RAISERROR('Procedure DBATools.dba.CaptureDatabaseSizes does not exist. Please create it first.', 16, 1);
    RETURN;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Capture Database Sizes',
    @description = 'Records database size metrics every hour',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Capture Database Sizes',
    @step_name = 'Capture Database Sizes',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureDatabaseSizes;',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Hourly
IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'Hourly_DatabaseSizes')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = 'Hourly_DatabaseSizes';
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Hourly_DatabaseSizes',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 60;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Capture Database Sizes',
    @schedule_name = 'Hourly_DatabaseSizes';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Capture Database Sizes',
    @server_name = @@SERVERNAME;
GO

/* ====================================================== */
-- Job: DBATools - Purge Old Data (daily at midnight)
/* ====================================================== */

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Purge Old Data')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Purge Old Data', @delete_unused_schedule = 1;
GO

-- Check that procedure exists before adding job step
IF OBJECT_ID(N'[DBATools].[dba].[PurgeOldData]') IS NULL
BEGIN
    RAISERROR('Procedure DBATools.dba.PurgeOldData does not exist. Please create it first.', 16, 1);
    RETURN;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Purge Old Data',
    @description = 'Removes data older than retention period (default 30 days)',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Purge Old Data',
    @step_name = 'Purge Old Data',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.PurgeOldData @RetentionDays = 30;',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Daily at midnight
IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'DailyMidnight_PurgeOldData')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = 'DailyMidnight_PurgeOldData';
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'DailyMidnight_PurgeOldData',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 0;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Purge Old Data',
    @schedule_name = 'DailyMidnight_PurgeOldData';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Purge Old Data',
    @server_name = @@SERVERNAME;
GO

/* ====================================================== */
-- Job: DBATools - Capture Query Stats (every 30 minutes)
/* ====================================================== */

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Capture Query Stats')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Capture Query Stats', @delete_unused_schedule = 1;
GO

-- Check that procedure exists before adding job step
IF OBJECT_ID(N'[DBATools].[dba].[CaptureQueryStats]') IS NULL
BEGIN
    RAISERROR('Procedure DBATools.dba.CaptureQueryStats does not exist. Please create it first.', 16, 1);
    RETURN;
END
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Capture Query Stats',
    @description = 'Captures top resource-consuming queries',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Capture Query Stats',
    @step_name = 'Capture Query Stats',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureQueryStats @Top = 100, @MinElapsedMS = 1000;',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

-- Schedule: Every 30 minutes
IF EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'Every30Minutes_QueryStats')
    EXEC msdb.dbo.sp_delete_schedule @schedule_name = 'Every30Minutes_QueryStats';
EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every30Minutes_QueryStats',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 30;
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Capture Query Stats',
    @schedule_name = 'Every30Minutes_QueryStats';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Capture Query Stats',
    @server_name = @@SERVERNAME;
GO

/* ====================================================== */
-- Create DBATools category if it doesn't exist
/* ====================================================== */

IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name = 'DBATools' AND category_class = 1)
    EXEC msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = 'DBATools';
GO

PRINT 'Agent jobs created successfully.';
PRINT '';
PRINT 'Jobs enabled:';
PRINT '  - DBATools - Capture Wait Stats (every 15 min)';
PRINT '  - DBATools - Capture Performance Counters (every 5 min)';
PRINT '  - DBATools - Capture Database Sizes (hourly)';
PRINT '  - DBATools - Capture Query Stats (every 30 min)';
PRINT '  - DBATools - Purge Old Data (daily midnight)';
PRINT '';
PRINT 'Note: Each job validates that its corresponding procedure exists before attempting to create the job step.';
PRINT 'Note: All schedules use unique names to avoid conflicts on repeated script runs.';
