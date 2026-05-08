-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE master;
GO

-- Drop existing trigger if present
IF EXISTS (SELECT * FROM sys.server_triggers WHERE name = 'trg_LoginAudit')
    DROP TRIGGER trg_LoginAudit ON ALL SERVER;
GO

CREATE TRIGGER trg_LoginAudit
ON ALL SERVER
FOR LOGON
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LoginName NVARCHAR(128) = ORIGINAL_LOGIN();
    DECLARE @SessionID INT = @@SPID;
    DECLARE @HostName NVARCHAR(128);
    DECLARE @ProgramName NVARCHAR(256);
    DECLARE @IPAddress NVARCHAR(50);

    -- Skip system connections
    IF @LoginName IN ('sa', 'NT AUTHORITY\SYSTEM', 'NT SERVICE\SQLSERVERAGENT', 'NT SERVICE\SQLTELEMETRY')
        RETURN;

    BEGIN TRY
        -- Get session info
        SELECT
            @HostName = COALESCE(host_name, 'Unknown'),
            @ProgramName = COALESCE(program_name, 'Unknown')
        FROM sys.dm_exec_sessions
        WHERE session_id = @SessionID;

        -- Get client IP
        SELECT @IPAddress = COALESCE(
            (SELECT client_net_address FROM sys.dm_exec_connections WHERE session_id = @SessionID),
            'Unknown'
        );

        -- Log to DBATools (use a separate transaction so it doesn't affect the login)
        IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'DBATools')
        BEGIN
            BEGIN TRY
                INSERT INTO DBATools.dba.LoginAudit (
                    ServerName, LoginName, SessionID, HostName, ProgramName,
                    IPAddress, EventType, IsSuccessful
                )
                VALUES (
                    @@SERVERNAME, @LoginName, @SessionID, @HostName, @ProgramName,
                    @IPAddress, 'LOGIN', 1
                );
            END TRY
            BEGIN CATCH
                -- Silently fail - don't disrupt login
            END CATCH
        END
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
PRINT 'The trigger is designed to silently fail and NOT block logins.';
