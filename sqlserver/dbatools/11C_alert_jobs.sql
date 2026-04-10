-- ============================================================================
-- Script: 11C_alert_jobs.sql
-- Purpose: Schedule alert check jobs
-- Usage:   Run after 11B_mail_setup.sql (mail must be configured)
-- Notes:   Adjust email recipients for your environment
-- ============================================================================

USE msdb;
GO

-- Alert Check Job (every 5 minutes)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Alert Check')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Alert Check', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Alert Check',
    @description = 'Checks configured alerts and sends notifications',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Alert Check',
    @step_name = 'Run Alert Checks',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CheckAlerts;',
    @database_name = 'DBATools';
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every5Minutes',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 5;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Alert Check',
    @schedule_name = 'Every5Minutes';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Alert Check',
    @server_name = @@SERVERNAME;
GO

-- Blocking Alert Job (every minute)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Blocking Alert')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Blocking Alert', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Blocking Alert',
    @description = 'Monitors for long-running blocking sessions',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Blocking Alert',
    @step_name = 'Check Blocking',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CheckBlockingAlert 
                @ThresholdSeconds = 30,
                @EmailRecipients = ''dba-team@yourcompany.com'';',  -- MODIFY THIS
    @database_name = 'DBATools';
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every1Minute',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 1;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Blocking Alert',
    @schedule_name = 'Every1Minute';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Blocking Alert',
    @server_name = @@SERVERNAME;
GO

-- Error Log Capture Job (every 15 minutes)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Error Log Capture')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Error Log Capture', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Error Log Capture',
    @description = 'Archives SQL error log for analysis',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Error Log Capture',
    @step_name = 'Capture Error Log',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureErrorLog @DaysToCapture = 7;',
    @database_name = 'DBATools';
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Every15Minutes',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 4,
    @freq_subday_interval = 15;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Error Log Capture',
    @schedule_name = 'Every15Minutes';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Error Log Capture',
    @server_name = @@SERVERNAME;
GO

-- Security Audit Jobs (daily at 8 AM)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Security Audit')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Security Audit', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Security Audit',
    @description = 'Captures login and role membership changes',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Security Audit',
    @step_name = 'Audit Logins',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureLoginAudit; EXEC DBATools.dba.CaptureRoleMembership;',
    @database_name = 'DBATools';
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Daily8AM',
    @freq_type = 4,
    @freq_interval = 1,
    @freq_subday_type = 1,
    @freq_subday_interval = 0,
    @freq_hour = 8;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Security Audit',
    @schedule_name = 'Daily8AM';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Security Audit',
    @server_name = @@SERVERNAME;
GO

PRINT 'Alert jobs created:';
PRINT '  - DBATools - Alert Check (every 5 min)';
PRINT '  - DBATools - Blocking Alert (every 1 min)';
PRINT '  - DBATools - Error Log Capture (every 15 min)';
PRINT '  - DBATools - Security Audit (daily 8 AM)';
PRINT '';
PRINT 'NOTE: Modify @EmailRecipients in blocking alert step before enabling.';
