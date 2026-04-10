-- ============================================================================
-- Script: 09_security_audit.sql
-- Purpose: Security audit tables and procedures
-- Usage:   Run after 01_tables.sql; schedule 09B_audit_jobs.sql separately
-- Notes:   Tracks login/role/permission changes for compliance
-- ============================================================================

USE DBATools;
GO

-- ============================================================================
-- Tables
-- ============================================================================

CREATE TABLE dba.SecurityAuditLogins (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    AuditTime DATETIME DEFAULT GETDATE(),
    LoginName NVARCHAR(128),
    LoginType NVARCHAR(50),
    CreateDate DATETIME,
    ModifyDate DATETIME,
    PasswordPolicyEnforce BIT,
    IsDisabled BIT,
    ActionType NVARCHAR(20), -- CREATED, MODIFIED, DROPPED, DISABLED
    LoginSid VARBINARY(85)
);
GO

CREATE TABLE dba.SecurityAuditRoleMembers (
    AuditID BIGIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    AuditTime DATETIME DEFAULT GETDATE(),
    DatabaseName NVARCHAR(128),
    RoleName NVARCHAR(128),
    MemberName NVARCHAR(128),
    MemberType NVARCHAR(20), -- SQL_USER, WINDOWS_USER, WINDOWS_GROUP
    ActionType NVARCHAR(20), -- ADDED, REMOVED
    ChangedBy NVARCHAR(128)
);
GO

CREATE TABLE dba.SecurityAuditPermissions (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    AuditTime DATETIME DEFAULT GETDATE(),
    DatabaseName NVARCHAR(128),
    GranteeName NVARCHAR(128),
    GrantorName NVARCHAR(128),
    PermissionType NVARCHAR(128),
    PermissionState NVARCHAR(20),
    ObjectName NVARCHAR(256),
    ObjectType NVARCHAR(20),
    ActionType NVARCHAR(20), -- GRANT, REVOKE, DENY
    ChangedBy NVARCHAR(128)
);
GO

CREATE TABLE dba.SecurityAuditDDL (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    EventTime DATETIME DEFAULT GETDATE(),
    LoginName NVARCHAR(128),
    HostName NVARCHAR(128),
    ObjectName NVARCHAR(256),
    ObjectType NVARCHAR(50),
    DDLCommand NVARCHAR(MAX),
    CommandType NVARCHAR(100)
);
GO

CREATE INDEX IX_SecurityAuditLogins_Time ON dba.SecurityAuditLogins(AuditTime);
CREATE INDEX IX_SecurityAuditLogins_Login ON dba.SecurityAuditLogins(LoginName);
CREATE INDEX IX_SecurityAuditRoleMembers_Time ON dba.SecurityAuditRoleMembers(AuditTime);
CREATE INDEX IX_SecurityAuditPermissions_Time ON dba.SecurityAuditPermissions(AuditTime);
CREATE INDEX IX_SecurityAuditDDL_Time ON dba.SecurityAuditDDL(EventTime);
GO

-- ============================================================================
-- Procedures
-- ============================================================================

CREATE OR ALTER PROCEDURE dba.CaptureLoginAudit
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentLogins TABLE (
        LoginName NVARCHAR(128),
        LoginType NVARCHAR(50),
        CreateDate DATETIME,
        ModifyDate DATETIME,
        PasswordPolicyEnforce BIT,
        IsDisabled BIT,
        LoginSid VARBINARY(85)
    );
    
    INSERT INTO @CurrentLogins
    SELECT name, type_desc, create_date, modify_date, 
           is_policy_checked, is_expiration_checked, sid
    FROM sys.server_principals
    WHERE type IN ('S', 'U', 'G', 'C', 'K')
      AND name NOT LIKE '##%';
    
    -- Find new logins
    INSERT INTO dba.SecurityAuditLogins (
        ServerName, LoginName, LoginType, CreateDate, ModifyDate,
        PasswordPolicyEnforce, IsDisabled, ActionType, LoginSid
    )
    SELECT 
        @ServerName,
        cl.LoginName,
        cl.LoginType,
        cl.CreateDate,
        cl.ModifyDate,
        cl.PasswordPolicyEnforce,
        cl.IsDisabled,
        'CREATED',
        cl.LoginSid
    FROM @CurrentLogins cl
    WHERE NOT EXISTS (
        SELECT 1 FROM dba.SecurityAuditLogins a
        WHERE a.LoginName = cl.LoginName 
          AND a.ServerName = @ServerName
          AND a.ActionType = 'CREATED'
    );
    
    -- Find dropped logins
    INSERT INTO dba.SecurityAuditLogins (
        ServerName, LoginName, ActionType
    )
    SELECT 
        @ServerName,
        LoginName,
        'DROPPED'
    FROM dba.SecurityAuditLogins
    WHERE ServerName = @ServerName
      AND ActionType = 'CREATED'
      AND LoginName NOT IN (SELECT LoginName FROM @CurrentLogins);
    
    PRINT 'Login audit captured for ' + @ServerName;
END
GO

CREATE OR ALTER PROCEDURE dba.CaptureRoleMembership
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CurrentMembers TABLE (
        DatabaseName NVARCHAR(128),
        RoleName NVARCHAR(128),
        MemberName NVARCHAR(128),
        MemberType NVARCHAR(20)
    );
    
    -- Server roles
    INSERT INTO @CurrentMembers
    SELECT 
        'master',
        r.name,
        m.name,
        m.type_desc
    FROM sys.server_role_members rm
    JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
    JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id;
    
    -- Database roles (all user databases)
    DECLARE @DBName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);
    
    DECLARE db_cursor CURSOR FOR
    SELECT name FROM sys.databases WHERE state_desc = 'ONLINE' AND is_read_only = 0;
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DBName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'USE [' + @DBName + ']; SELECT ''' + @DBName + ''', r.name, m.name, m.type_desc 
                    FROM sys.database_role_members rm
                    JOIN sys.database_principals r ON rm.role_principal_id = r.principal_id
                    JOIN sys.database_principals m ON rm.member_principal_id = m.principal_id';
        
        BEGIN TRY
            INSERT INTO @CurrentMembers
            EXEC sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            -- Skip databases we can't access
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DBName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    -- Find new members
    INSERT INTO dba.SecurityAuditRoleMembers (
        ServerName, DatabaseName, RoleName, MemberName, MemberType, ActionType
    )
    SELECT 
        @ServerName,
        cm.DatabaseName,
        cm.RoleName,
        cm.MemberName,
        cm.MemberType,
        'ADDED'
    FROM @CurrentMembers cm
    WHERE NOT EXISTS (
        SELECT 1 FROM dba.SecurityAuditRoleMembers a
        WHERE a.ServerName = @ServerName
          AND a.DatabaseName = cm.DatabaseName
          AND a.RoleName = cm.RoleName
          AND a.MemberName = cm.MemberName
          AND a.ActionType = 'ADDED'
    );
    
    PRINT 'Role membership audit captured for ' + @ServerName;
END
GO

CREATE OR ALTER PROCEDURE dba.CaptureServerPermissions
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.SecurityAuditPermissions (
        ServerName, DatabaseName, GranteeName, GrantorName, 
        PermissionType, PermissionState, ObjectName, ObjectType, ActionType
    )
    SELECT 
        @ServerName,
        'master',
        pr.name,
        grantor.name,
        pe.permission_name,
        pe.state_desc,
        OBJECT_NAME(pe.major_id),
        'SERVER',
        'GRANT'
    FROM sys.server_permissions pe
    JOIN sys.server_principals pr ON pe.grantee_principal_id = pr.principal_id
    JOIN sys.server_principals grantor ON pe.grantor_principal_id = grantor.principal_id
    WHERE pe.class = 100; -- Server
    
    PRINT 'Server permissions audit captured for ' + @ServerName;
END
GO

PRINT 'Security audit tables and procedures created.';
PRINT 'Run 09B_security_jobs.sql to schedule regular captures.';
