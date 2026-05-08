-- ============================================================================
-- Script: test_dbatools_installation.sql
-- Purpose: Verify DBATools database objects are correctly deployed
-- Usage:   Run against DBATools database after deployment
-- ============================================================================

USE DBATools;
GO

SET NOCOUNT ON;

PRINT '========================================';
PRINT 'DBATools Installation Verification';
PRINT 'Server: ' + @@SERVERNAME;
PRINT '========================================';
PRINT '';

-- Check database exists
IF DB_ID('DBATools') IS NOT NULL
    PRINT '[PASS] DBATools database exists';
ELSE
    PRINT '[FAIL] DBATools database does not exist';
PRINT '';

-- Check schema
IF EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dba')
    PRINT '[PASS] dba schema exists';
ELSE
    PRINT '[FAIL] dba schema does not exist';
PRINT '';

-- Check core tables
PRINT '--- Core Tables ---';
SELECT 
    t.name AS TableName,
    CASE WHEN EXISTS (SELECT 1 FROM sys.columns c WHERE c.object_id = t.object_id) THEN 'OK' ELSE 'EMPTY' END AS Status
FROM sys.tables t
WHERE t.schema_id = SCHEMA_ID('dba')
ORDER BY t.name;

PRINT '';
PRINT '--- Stored Procedures ---';
SELECT COUNT(*) AS ProcedureCount FROM sys.procedures WHERE schema_id = SCHEMA_ID('dba');

PRINT '';
PRINT '--- Views ---';
SELECT COUNT(*) AS ViewCount FROM sys.views WHERE schema_id = SCHEMA_ID('dba');

PRINT '';
PRINT '--- Functions ---';
SELECT COUNT(*) AS FunctionCount FROM sys.objects WHERE type IN ('FN','IF','TF') AND schema_id = SCHEMA_ID('dba');

PRINT '';
PRINT '--- Agent Jobs ---';
SELECT COUNT(*) AS JobCount FROM msdb.dbo.sysjobs WHERE name LIKE 'DBATools -%';

PRINT '';
PRINT '========================================';
PRINT 'Verification Complete';
PRINT '========================================';