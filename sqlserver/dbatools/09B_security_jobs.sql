-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE msdb;
GO

-- Create Daily8AM schedule (daily at 8:00 AM) if it does not exist
-- Fixed: Replaced invalid @freq_hour parameter with @active_start_time
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysschedules WHERE name = 'Daily8AM')
BEGIN
    EXEC msdb.dbo.sp_add_schedule
        @schedule_name = 'Daily8AM',
        @freq_type = 4, -- Daily
        @freq_interval = 1, -- Every 1 day
        @active_start_time = 080000; -- 8:00 AM in HHMMSS format
END
GO

-- Security Audit - Login Capture (daily at 8 AM)
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

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Security Audit - Logins',
    @schedule_name = 'Daily8AM';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Security Audit - Logins',
    @server_name = @@SERVERNAME;
GO

-- Security Audit - Role Members (daily at 8 AM)
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
GO
