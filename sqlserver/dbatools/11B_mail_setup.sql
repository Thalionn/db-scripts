-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE msdb;
GO

-- ============================================================================
-- CONFIGURATION - MODIFY THESE VALUES
-- ============================================================================

DECLARE @EmailProfile NVARCHAR(128) = 'DBATools';
DECLARE @EmailAccount NVARCHAR(128) = 'DBATools';
DECLARE @EmailDescription NVARCHAR(256) = 'DBATools Alerting';
DECLARE @SenderEmail NVARCHAR(256) = 'sqlalerts@yourcompany.com';
DECLARE @SenderName NVARCHAR(256) = 'SQL Server Alerts';

-- SMTP Server Configuration - MODIFY THESE
DECLARE @SMTPServer NVARCHAR(128) = 'smtp.yourcompany.com';
DECLARE @SMTPPort INT = 587;
DECLARE @UseSSL BIT = 1;

-- Authentication - MODIFY THESE or use Windows Auth
DECLARE @SMTPUser NVARCHAR(256) = 'sqlalerts@yourcompany.com';
DECLARE @SMTPPassword NVARCHAR(256) = 'YourSecurePassword'; -- Use a credential instead in production!

-- ============================================================================
-- END CONFIGURATION
-- ============================================================================

-- Enable Database Mail
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
GO

-- Create Database Mail Profile
EXEC msdb.dbo.sp_add_profile 
    @profile_name = 'DBATools',
    @description = 'Profile for DBATools alerts and notifications';
GO

-- Create Database Mail Account
EXEC msdb.dbo.sp_add_account
    @account_name = 'DBATools',
    @description = 'Account for DBATools alerting',
    @email_address = 'sqlalerts@yourcompany.com',
    @display_name = 'SQL Server Alerts',
    @mailserver_name = 'smtp.yourcompany.com',
    @mailserver_type = 'SMTP',
    @port = 587,
    @use_tls = 'StartTLS',
    @username = 'sqlalerts@yourcompany.com',
    @password = 'YourSecurePassword'; -- In production, use sp_add_credential
GO

-- Add account to profile
EXEC msdb.dbo.sp_add_profileaccount
    @profile_name = 'DBATools',
    @account_name = 'DBATools',
    @sequence_number = 1;
GO

-- Set profile as default
EXEC msdb.dbo.sp_add_principalprofile
    @profile_name = 'DBATools',
    @principal_name = 'public',
    @is_default = 1;
GO

-- Create Operator for alerts
EXEC msdb.dbo.sp_add_operator
    @name = 'DBATools_Admin',
    @enabled = 1,
    @email_address = 'dba-team@yourcompany.com',
    @pager_address = NULL,
    @category_name = 'DBATools';
GO

-- Test email (run manually)
-- EXEC msdb.dbo.sp_send_dbmail
--     @profile_name = 'DBATools',
--     @recipients = 'dba-team@yourcompany.com',
--     @subject = 'Database Mail Test',
--     @body = 'Database Mail is configured successfully.',
--     @body_format = 'TEXT';
GO

PRINT '============================================================';
PRINT '!!! IMPORTANT: MAIL SERVER SETUP REQUIRED !!!';
PRINT '============================================================';
PRINT '';
PRINT 'This script creates the mail profile but requires:';
PRINT '';
PRINT '1. SMTP Server Details:';
PRINT '   - Update @SMTPServer, @SMTPPort, @UseSSL in script';
PRINT '   - Or configure via SSMS > Management > Database Mail';
PRINT '';
PRINT '2. Authentication:';
PRINT '   - Replace password with SQL Credential in production';
PRINT '   - Use Windows Auth if SMTP supports it';
PRINT '';
PRINT '3. Test the configuration:';
PRINT '   EXEC msdb.dbo.sp_send_dbmail';
PRINT '       @profile_name = ''DBATools'',';
PRINT '       @recipients = ''your@email.com'',';
PRINT '       @subject = ''Test'',';
PRINT '       @body = ''Test message'';';
PRINT '';
PRINT '4. Firewall/network access to SMTP port required';
PRINT '';
PRINT '5. Once mail is working, run:';
PRINT '   - 11C_alert_jobs.sql for scheduled alert checks';
PRINT '============================================================';
