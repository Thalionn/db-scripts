-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.LoginTransferScript (
    ScriptID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    LoginName NVARCHAR(256),
    LoginType NVARCHAR(20),
    SID VARBINARY(85),
    PasswordHash VARBINARY(256),
    DefaultDatabase NVARCHAR(128),
    Language NVARCHAR(128),
    CreateScript NVARCHAR(MAX),
    Notes NVARCHAR(MAX),
    INDEX IX_Login_Capture NONCLUSTERED (CaptureTime, LoginName)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureLoginsForTransfer
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @GenerateScriptOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;

    IF @GenerateScriptOnly = 0
    BEGIN
        TRUNCATE TABLE dba.LoginTransferScript;
    END;

    INSERT INTO dba.LoginTransferScript (
        ServerName, LoginName, LoginType, SID, PasswordHash, 
        DefaultDatabase, Language, CreateScript
    )
    SELECT 
        @ServerName,
        p.name AS LoginName,
        p.type_desc AS LoginType,
        p.sid,
        p.password_hash,
        p.default_database_name,
        p.default_language_name,
        CASE p.type_desc
            WHEN 'SQL_LOGIN' THEN 
                'USE [master];' + CHAR(13) + CHAR(10) +
                'CREATE LOGIN [' + p.name + '] WITH PASSWORD = ' + 
                CONVERT(VARCHAR(256), p.password_hash, 1) + ' HASHED, ' +
                'SID = ' + CONVERT(VARCHAR(256), p.sid, 1) + ', ' +
                'DEFAULT_DATABASE = [' + ISNULL(p.default_database_name, 'master') + '], ' +
                'DEFAULT_LANGUAGE = [' + ISNULL(p.default_language_name, 'us_english') + '];'
            WHEN 'WINDOWS_LOGIN' THEN
                'USE [master];' + CHAR(13) + CHAR(10) +
                'CREATE LOGIN [' + p.name + '] FROM WINDOWS WITH ' +
                'DEFAULT_DATABASE = [' + ISNULL(p.default_database_name, 'master') + '], ' +
                'DEFAULT_LANGUAGE = [' + ISNULL(p.default_language_name, 'us_english') + '];'
            WHEN 'CERTIFICATE_MAPPED_LOGIN' THEN
                'USE [master];' + CHAR(13) + CHAR(10) +
                'CREATE LOGIN [' + p.name + '] FROM CERTIFICATE [' + c.name + '];'
            WHEN 'ASYMMETRIC_KEY_MAPPED_LOGIN' THEN
                'USE [master];' + CHAR(13) + CHAR(10) +
                'CREATE LOGIN [' + p.name + '] FROM ASYMMETRIC KEY [' + ak.name + '];'
            ELSE '-- Unsupported login type: ' + p.type_desc
        END AS CreateScript
    FROM sys.server_principals p
    LEFT JOIN sys.certificates c ON p.name = c.name
    LEFT JOIN sys.asymmetric_keys ak ON p.name = ak.name
    WHERE p.type IN ('S', 'U', 'G', 'C', 'K')
      AND p.name NOT LIKE '##%'
      AND p.name NOT IN ('sa', 'NT AUTHORITY\SYSTEM', 'NT SERVICE\%', 'BUILTIN\%')
    ORDER BY p.type, p.name;

    SELECT @ServerName AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS LoginsCaptured;
END
GO

CREATE OR ALTER PROCEDURE dba.GenerateLoginTransferScript
    @OutputDatabaseName NVARCHAR(128) = NULL,
    @OutputTableName NVARCHAR(256) = 'LoginTransferScript'
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '-- ============================================================';
    PRINT '-- Login Transfer Script';
    PRINT '-- Source Server: ' + @@SERVERNAME;
    PRINT '-- Generated: ' + CAST(GETDATE() AS VARCHAR);
    PRINT '-- ============================================================';
    PRINT '';

    PRINT '-- ============================================================';
    PRINT '-- STEP 1: Create Logins (Run on target server first)';
    PRINT '-- ============================================================';
    PRINT '';

    SELECT CreateScript
    FROM dba.LoginTransferScript
    WHERE LoginType IN ('SQL_LOGIN', 'WINDOWS_LOGIN')
    ORDER BY LoginName;

    PRINT '';
    PRINT '-- ============================================================';
    PRINT '-- STEP 2: Transfer Server Role Memberships';
    PRINT '-- ============================================================';
    PRINT '';

    SELECT 
        'EXEC sp_addsrvrolemember ''' + l.name + ''', ''' + r.name + ''';'
        AS RoleAssignmentScript,
        l.name AS LoginName,
        r.name AS ServerRole
    FROM sys.server_principals l
    JOIN sys.server_role_members rm ON l.principal_id = rm.member_principal_id
    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
    WHERE l.name NOT LIKE '##%'
      AND l.name NOT IN ('sa', 'NT AUTHORITY\SYSTEM', 'BUILTIN\%')
    ORDER BY r.name, l.name;

    PRINT '';
    PRINT '-- ============================================================';
    PRINT '-- STEP 3: Transfer Database Users and Role Memberships';
    PRINT '-- ============================================================';
    PRINT '';
    PRINT '-- Note: Run for each database that needs migration';
    PRINT '-- Example for a single database:';
    PRINT '';
    PRINT '-- USE [YourDatabase];';
    PRINT '-- EXEC dba.GenerateDatabaseUserScript @DatabaseName = ''YourDatabase'';';
    PRINT '';
END
GO

CREATE OR ALTER PROCEDURE dba.GenerateDatabaseUserScript
    @DatabaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = @DatabaseName AND state = 0)
    BEGIN
        SELECT 'Database ' + @DatabaseName + ' does not exist or is not online.' AS Error;
        RETURN;
    END;

    DECLARE @SQL NVARCHAR(MAX) = N'
    PRINT ''-- Database: ' + @DatabaseName + ''';
    PRINT ''''

    PRINT ''-- STEP 1: Create Users for Logins''
    PRINT 'USE [' + @DatabaseName + '];''
    PRINT ''''

    SELECT 
        ''CREATE USER ['' + dp.name + ''] FOR LOGIN ['' + sp.name + ''];''
        AS CreateUserScript,
        dp.name AS DatabaseUser,
        sp.name AS ServerLogin,
        dp.default_schema_name
    FROM $DatabaseName$.sys.database_principals dp
    JOIN sys.server_principals sp ON dp.sid = sp.sid
    WHERE dp.type IN (''S'', ''U'', ''G'')
      AND dp.name NOT LIKE ''##%''
    ORDER BY dp.name;

    PRINT ''''
    PRINT ''-- STEP 2: Add Users to Database Roles''
    PRINT ''''

    SELECT 
        ''EXEC sp_addrolemember '''''' + dr.name + '''''', '''' + dp.name + '''''';''
        AS RoleMembershipScript,
        dp.name AS DatabaseUser,
        dr.name AS DatabaseRole
    FROM $DatabaseName$.sys.database_principals dp
    JOIN $DatabaseName$.sys.database_role_members drm ON dp.principal_id = drm.member_principal_id
    JOIN $DatabaseName$.sys.database_principals dr ON drm.role_principal_id = dr.principal_id
    WHERE dp.name NOT LIKE ''##%''
    ORDER BY dr.name, dp.name;
    ';

    SET @SQL = REPLACE(@SQL, '$DatabaseName$', @DatabaseName);

    EXEC sp_executesql @SQL;
END
GO

CREATE OR ALTER PROCEDURE dba.CompareLogins
    @SourceServer NVARCHAR(128),
    @TargetServer NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '-- ============================================================';
    PRINT '-- Login Comparison Report';
    PRINT '-- Source: ' + @SourceServer;
    PRINT '-- Target: ' + @TargetServer;
    PRINT '-- ============================================================';
    PRINT '';

    PRINT '-- ============================================================';
    PRINT '-- Logins in source but missing in target';
    PRINT '-- ============================================================';
    PRINT '';

    SELECT LoginName, LoginType, DefaultDatabase
    FROM dba.LoginTransferScript
    WHERE ServerName = @SourceServer
      AND LoginName NOT IN (
          SELECT name FROM sys.server_principals 
          WHERE type IN ('S', 'U', 'G')
      )
    ORDER BY LoginName;

    PRINT '';
    PRINT '-- ============================================================';
    PRINT '-- Logins in target but not in source';
    PRINT '-- ============================================================';
    PRINT '';

    SELECT name AS LoginName, type_desc AS LoginType, default_database_name AS DefaultDatabase
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G')
      AND name NOT IN (
          SELECT LoginName FROM dba.LoginTransferScript WHERE ServerName = @SourceServer
      )
      AND name NOT LIKE '##%'
    ORDER BY name;
END
GO

PRINT 'Login transfer procedures created.';
PRINT '';
PRINT 'Usage:';
PRINT '  1. On SOURCE server:';
PRINT '     EXEC dba.CaptureLoginsForTransfer;';
PRINT '';
PRINT '  2. Export results or script:';
PRINT '     SELECT * FROM dba.LoginTransferScript;';
PRINT '     EXEC dba.GenerateLoginTransferScript;';
PRINT '';
PRINT '  3. On TARGET server:';
PRINT '     INSERT INTO dba.LoginTransferScript (ServerName, LoginName, ...)';
PRINT '     -- Or run the CREATE LOGIN scripts directly';
PRINT '';
PRINT '  4. Transfer database roles per database:';
PRINT '     EXEC dba.GenerateDatabaseUserScript @DatabaseName = ''YourDB'';';
