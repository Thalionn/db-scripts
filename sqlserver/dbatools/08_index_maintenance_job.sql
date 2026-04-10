-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.

USE msdb;
GO

IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Index Maintenance')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Index Maintenance', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Index Maintenance',
    @description = 'Rebuilds or reorganizes fragmented indexes based on thresholds',
    @category_name = 'DBATools',
    @enabled = 1;
GO

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Index Maintenance',
    @step_name = 'User Databases',
    @subsystem = 'TSQL',
    @command = '
DECLARE @DatabaseName NVARCHAR(128);
DECLARE @DatabaseList CURSOR;

SET @DatabaseList = CURSOR FOR
SELECT name 
FROM sys.databases 
WHERE state_desc = ''ONLINE'' 
  AND is_read_only = 0
  AND name NOT IN (''master'', ''model'', ''msdb'', ''tempdb'', ''DBATools'');

OPEN @DatabaseList;
FETCH NEXT FROM @DatabaseList INTO @DatabaseName;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC DBATools.dba.IndexMaintenance
        @DatabaseName = @DatabaseName,
        @MinFragPercent = 5,
        @RebuildThreshold = 30,
        @MinPageCount = 1000;
    
    FETCH NEXT FROM @DatabaseList INTO @DatabaseName;
END

CLOSE @DatabaseList;
DEALLOCATE @DatabaseList;
',
    @database_name = 'DBATools',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_schedule
    @schedule_name = 'Sunday2AM',
    @freq_type = 8,
    @freq_interval = 64,
    @freq_recurrence_factor = 1;

EXEC msdb.dbo.sp_attach_schedule
    @job_name = 'DBATools - Index Maintenance',
    @schedule_name = 'Sunday2AM';
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Index Maintenance',
    @server_name = @@SERVERNAME;
GO

PRINT 'Index maintenance job created (runs Sundays at 2 AM).';
PRINT 'Customize thresholds in 02_procedures.sql IndexMaintenance procedure.';
