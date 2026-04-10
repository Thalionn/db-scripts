-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 09B_security_jobs.sql
-- Purpose: Schedule security audit collection jobs
-- Usage:   Run after 09_security_audit.sql
-- Notes:   Capture is daily; increase frequency if needed
-- ============================================================================

USE msdb;
GO

-- Security Audit - Login Capture (daily)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Security Audit - Logins')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Security Audit - Logins', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Security Audit - Logins',
    @description = 'Captures login changes daily',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Security Audit - Logins',
    @step_name = 'Capture Logins',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureLoginAudit;',
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
    @job_name = 'DBATools - Security Audit - Logins',
    @schedule_name = 'Daily8AM';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Security Audit - Logins',
    @server_name = @@SERVERNAME;
GO

-- Security Audit - Role Members (daily)
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Security Audit - Roles')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Security Audit - Roles', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Security Audit - Roles',
    @description = 'Captures role membership changes daily',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Security Audit - Roles',
    @step_name = 'Capture Role Members',
    @subsystem = 'TSQL',
    @command = 'EXEC DBATools.dba.CaptureRoleMembership;',
    @database_name = 'DBATools';
GO

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Security Audit - Roles',
    @schedule_name = 'Daily8AM';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Security Audit - Roles',
    @server_name = @@SERVERNAME;
GO

PRINT 'Security audit jobs created (runs daily at 8 AM).';
