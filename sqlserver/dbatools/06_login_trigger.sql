-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 06_login_trigger.sql
-- Purpose: Server-level trigger for login auditing
-- Usage:   Run after 05_jobs.sql - enables login tracking
-- Notes:   Requires sysadmin or security admin to create
-- ============================================================================

USE master;
GO

-- Drop existing trigger if present
IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'trg_LoginAudit')
    DROP TRIGGER trg_LoginAudit ON ALL SERVER;
GO

CREATE TRIGGER trg_LoginAudit
ON ALL SERVER
WITH EXECUTE AS 'sa'
FOR LOGON
AS
BEGIN
    DECLARE @LoginName NVARCHAR(128) = ORIGINAL_LOGIN();
    DECLARE @SessionID INT = @@SPID;
    DECLARE @HostName NVARCHAR(128);
    DECLARE @ProgramName NVARCHAR(256);
    DECLARE @IPAddress NVARCHAR(50);
    DECLARE @EventType NVARCHAR(50) = 'LOGIN';
    
    -- Get session info
    SELECT 
        @HostName = COALESCE(host_name, 'Unknown'),
        @ProgramName = COALESCE(program_name, 'Unknown')
    FROM sys.dm_exec_sessions
    WHERE session_id = @@SPID;
    
    -- Get client IP from connection info
    SELECT @IPAddress = COALESCE(
        (SELECT client_net_address FROM sys.dm_exec_connections WHERE session_id = @@SPID),
        'Unknown'
    );
    
    -- Skip system connections
    IF @LoginName IN ('sa', 'NT AUTHORITY\SYSTEM', 'NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLTELEMETRY')
        RETURN;
    
    -- Log to DBATools (ignore errors if DB not accessible)
    BEGIN TRY
        INSERT INTO DBATools.dba.LoginAudit (
            ServerName, LoginName, SessionID, HostName, ProgramName, 
            IPAddress, EventType, IsSuccessful
        )
        VALUES (
            @@SERVERNAME, @LoginName, @SessionID, @HostName, @ProgramName,
            @IPAddress, @EventType, 1
        );
    END TRY
    BEGIN CATCH
        -- Silently fail - don't disrupt login
    END CATCH
END;
GO

-- Enable trigger
ENABLE TRIGGER trg_LoginAudit ON ALL SERVER;
GO

PRINT 'Login audit trigger created and enabled.';
PRINT 'All logins will now be tracked in DBATools.dba.LoginAudit.';
