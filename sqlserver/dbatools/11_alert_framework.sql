-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 11_alert_framework.sql
-- Purpose: Database Mail and Alert configuration
-- Usage:   Run after 00_create_database.sql
-- Notes:   IMPORTANT: Configure Database Mail first!
--          See 11B_mail_setup.sql for mail configuration
-- ============================================================================

USE DBATools;
GO

-- ============================================================================
-- Alert Configuration Table
-- ============================================================================

CREATE TABLE dba.AlertConfiguration (
    AlertID INT IDENTITY(1,1) PRIMARY KEY,
    AlertName NVARCHAR(100) NOT NULL,
    AlertType NVARCHAR(50),
    CheckQuery NVARCHAR(MAX),
    ThresholdValue INT,
    ThresholdColumn NVARCHAR(100),
    Severity INT DEFAULT 120,
    IsEnabled BIT DEFAULT 1,
    NotifyOperator BIT DEFAULT 1,
    NotifyEmail NVARCHAR(256),
    NotificationMessage NVARCHAR(500),
    LastChecked DATETIME,
    LastTriggered DATETIME,
    TriggerCount INT DEFAULT 0,
    CONSTRAINT UQ_AlertName UNIQUE (AlertName)
);
GO

-- ============================================================================
-- Alert Definitions
-- ============================================================================

INSERT INTO dba.AlertConfiguration (AlertName, AlertType, ThresholdValue, Severity, NotifyEmail, NotificationMessage)
VALUES 
    ('Long Running Query', 'QUERY', 300, 120, NULL, 'Query running longer than {0} seconds'),
    ('Blocking Chain', 'BLOCKING', 5, 120, NULL, 'Blocking chain of {0} sessions detected'),
    ('Failed Logins', 'SECURITY', 5, 120, NULL, '{0} failed login attempts in last hour'),
    ('Database Full Backup Overdue', 'BACKUP', 24, 120, NULL, '{0} hours since last full backup'),
    ('Log Backup Overdue', 'BACKUP', 2, 120, NULL, '{0} hours since last log backup'),
    ('High Wait Time', 'PERFORMANCE', 1000, 120, NULL, 'Wait type {0} exceeds {1}ms'),
    ('Error Log Error', 'ERRORLOG', 1, 120, NULL, 'Errors found in SQL error log'),
    ('Disk Space Low', 'DISK', 90, 120, NULL, 'Disk {0} is {1}% full'),
    ('TempDB Contention', 'PERFORMANCE', 100, 120, NULL, 'TempDB PFS/GAM contention detected'),
    ('Job Failed', 'JOB', 1, 120, NULL, 'Job {0} failed');
GO

-- ============================================================================
-- Alert Check Procedures
-- ============================================================================

CREATE OR ALTER PROCEDURE dba.CheckAlerts
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @EmailBody NVARCHAR(MAX);
    DECLARE @AlertName NVARCHAR(100);
    DECLARE @Threshold INT;
    DECLARE @Email NVARCHAR(256);
    DECLARE @Message NVARCHAR(500);
    DECLARE @Results TABLE (AlertName NVARCHAR(100), CurrentValue INT, Message NVARCHAR(500));
    
    -- Check: Long Running Queries
    INSERT INTO @Results
    SELECT TOP 1
        'Long Running Query',
        DATEDIFF(SECOND, r.start_time, GETDATE()),
        'Query running for ' + CAST(DATEDIFF(SECOND, r.start_time, GETDATE()) AS VARCHAR) + ' seconds'
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.start_time < DATEADD(MINUTE, -5, GETDATE())
      AND r.cmd NOT IN ('TASK MANAGER', 'KASTASKMGR');
    
    -- Check: Blocking
    INSERT INTO @Results
    SELECT TOP 1
        'Blocking Chain',
        COUNT(DISTINCT r.session_id),
        CAST(COUNT(DISTINCT r.session_id) AS VARCHAR) + ' sessions in blocking chain'
    FROM sys.dm_exec_requests r
    WHERE r.blocking_session_id > 0;
    
    -- Check: Failed Logins (last hour)
    INSERT INTO @Results
    SELECT TOP 1
        'Failed Logins',
        COUNT(*),
        CAST(COUNT(*) AS VARCHAR) + ' failed logins in last hour'
    FROM dba.LoginAudit
    WHERE EventType = 'FAILED_LOGIN'
      AND LoginTime > DATEADD(HOUR, -1, GETDATE());
    
    -- Check: Backup Status
    INSERT INTO @Results
    SELECT TOP 1
        'Database Full Backup Overdue',
        DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()),
        'Database ' + DatabaseName + ': ' + CAST(DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) AS VARCHAR) + ' hours since backup'
    FROM dba.BackupHistory
    WHERE BackupType = 'D'
      AND BackupFinish < DATEADD(HOUR, -24, GETDATE())
    GROUP BY DatabaseName;
    
    -- Check: Job Failures
    INSERT INTO @Results
    SELECT TOP 1
        'Job Failed',
        COUNT(*),
        'Recent job failures detected'
    FROM msdb.dbo.sysjobhistory h
    WHERE run_date >= CONVERT(INT, CONVERT(VARCHAR, DATEADD(DAY, -1, GETDATE()), 112))
      AND run_status = 0;
    
    -- Send alerts for triggered conditions
    DECLARE alert_cursor CURSOR FOR
    SELECT r.AlertName, r.CurrentValue, r.Message, a.ThresholdValue, a.NotifyEmail, a.NotificationMessage
    FROM @Results r
    JOIN dba.AlertConfiguration a ON r.AlertName = a.AlertName
    WHERE a.IsEnabled = 1
      AND r.CurrentValue >= a.ThresholdValue;
    
    OPEN alert_cursor;
    FETCH NEXT FROM alert_cursor INTO @AlertName, @Threshold, @Message, @Threshold, @Email, @Message;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Update trigger count
        UPDATE dba.AlertConfiguration
        SET LastTriggered = GETDATE(),
            TriggerCount = TriggerCount + 1
        WHERE AlertName = @AlertName;
        
        -- Queue email (requires Database Mail configured)
        IF @Email IS NOT NULL
        BEGIN
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'DBATools',
                @recipients = @Email,
                @subject = 'SQL Server Alert: ' + @AlertName,
                @body = @Message,
                @body_format = 'TEXT';
        END
        
        FETCH NEXT FROM alert_cursor INTO @AlertName, @Threshold, @Message, @Threshold, @Email, @Message;
    END
    
    CLOSE alert_cursor;
    DEALLOCATE alert_cursor;
    
    -- Return results
    SELECT * FROM @Results;
END
GO

-- ============================================================================
-- Blocking Alert Trigger (on-demand check)
-- ============================================================================

CREATE OR ALTER PROCEDURE dba.CheckBlockingAlert
    @ThresholdSeconds INT = 30,
    @EmailRecipients NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @BlockingInfo NVARCHAR(MAX);
    
    SELECT @BlockingInfo = (
        SELECT 
            blocked.session_id AS BlockedSPID,
            blocker.session_id AS BlockerSPID,
            sblk.login_name AS BlockerLogin,
            sblk.host_name AS BlockerHost,
            DB_NAME(r.database_id) AS DatabaseName,
            SUBSTRING(t.text, 1, 200) AS BlockerQuery,
            r.wait_time AS WaitTimeMS,
            o.name AS LockedObject,
            w.wait_type AS WaitType
        FROM sys.dm_exec_requests blocked
        JOIN sys.dm_exec_requests blocker ON blocked.blocking_session_id = blocker.session_id
        LEFT JOIN sys.dm_exec_sessions sblk ON blocker.session_id = sblk.session_id
        LEFT JOIN sys.dm_exec_requests r ON blocker.session_id = r.request_id
        LEFT JOIN sys.dm_os_waiting_tasks w ON blocker.session_id = w.session_id
        CROSS APPLY sys.dm_exec_sql_text(blocker.sql_handle) t
        LEFT JOIN sys.dm_tran_locks tl ON blocker.session_id = tl.request_session_id
        LEFT JOIN sys.objects o ON tl.resource_associated_entity_id = o.object_id
        WHERE blocked.blocking_session_id > 0
          AND r.wait_time > (@ThresholdSeconds * 1000)
        FOR JSON PATH
    );
    
    IF @BlockingInfo IS NOT NULL
    BEGIN
        -- Log to alerts
        INSERT INTO dba.LoginAudit (LoginName, EventType, ErrorMessage, IsSuccessful)
        VALUES ('BLOCKING_ALERT', 'ALERT', LEFT(@BlockingInfo, 4000), 1);
        
        -- Send email if configured
        IF @EmailRecipients IS NOT NULL
        BEGIN
            EXEC msdb.dbo.sp_send_dbmail
                @profile_name = 'DBATools',
                @recipients = @EmailRecipients,
                @subject = 'SQL Server Blocking Alert - ' + @@SERVERNAME,
                @body = 'Blocking sessions detected exceeding threshold.' + CHAR(10) + CHAR(10) + @BlockingInfo,
                @body_format = 'TEXT';
        END
        
        SELECT 'ALERT_TRIGGERED' AS Status, @BlockingInfo AS Details;
    END
    ELSE
    BEGIN
        SELECT 'OK' AS Status;
    END
END
GO

-- ============================================================================
-- Views
-- ============================================================================

CREATE OR ALTER VIEW dba.vActiveAlerts
AS
SELECT 
    AlertName,
    AlertType,
    ThresholdValue,
    Severity,
    NotifyEmail,
    NotificationMessage,
    LastChecked,
    LastTriggered,
    TriggerCount,
    CASE 
        WHEN LastTriggered > DATEADD(HOUR, -1, GETDATE()) THEN 'RECENT'
        WHEN LastTriggered > DATEADD(DAY, -1, GETDATE()) THEN 'TODAY'
        ELSE 'STALE'
    END AS TriggerStatus
FROM dba.AlertConfiguration
WHERE IsEnabled = 1;
GO

CREATE OR ALTER VIEW dba.vAlertHistory
AS
SELECT 
    ServerName,
    CAST(LoginTime AS DATE) AS AlertDate,
    LoginName AS AlertName,
    ErrorMessage AS Details,
    COUNT(*) AS Occurrences
FROM dba.LoginAudit
WHERE EventType = 'ALERT'
GROUP BY ServerName, CAST(LoginTime AS DATE), LoginName, ErrorMessage;
GO

PRINT 'Alert framework created.';
PRINT '';
PRINT '!!! IMPORTANT: Database Mail must be configured before alerts will send emails !!!';
PRINT '';
PRINT 'Run 11B_mail_setup.sql to configure Database Mail profile.';
PRINT 'Then run 11C_alert_jobs.sql to schedule alert checks.';
