-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- DBATools Objects Verification Script
-- Verifies all DBATools database objects are properly installed
-- Run this on both servers after deployment
-- ============================================================================

USE DBATools;
GO

PRINT '========================================';
PRINT 'DBATools Installation Verification Script';
PRINT '========================================';
PRINT '';

-- =============================================
-- CHECK 1: Database Existence
-- =============================================
PRINT '--- CHECK 1: Database Existence ---';

IF DB_ID('DBATools') IS NOT NULL
BEGIN
    PRINT '  [OK] DBATools database exists';
END
ELSE
BEGIN
    PRINT '  [FAIL] DBATools database NOT found';
END

PRINT '';

-- =============================================
-- CHECK 2: Tables
-- =============================================
PRINT '--- CHECK 2: Tables ---';

DECLARE @TableCount INT = 0;

SELECT
    name AS TableName,
    CASE WHEN OBJECT_ID('dba.' + name, 'U') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Status
FROM (
    VALUES
        ('AGDatabaseSync'),
        ('AGReplicaHealth'),
        ('AlertConfiguration'),
        ('BackupHistory'),
        ('DatabaseDocumentation'),
        ('DatabaseSizeHistory'),
        ('DuplicateIndexAudit'),
        ('ErrorLogArchive'),
        ('ErrorLogSummary'),
        ('GrowthProjection'),
        ('IndexMaintenanceLog'),
        ('IndexRecommendations'),
        ('JobHistorySummary'),
        ('LoginAudit'),
        ('LoginTransferScript'),
        ('PerfCounters'),
        ('PerformanceBaseline'),
        ('PerformanceVariance'),
        ('QueryStatsSnapshot'),
        ('SecurityAuditDDL'),
        ('SecurityAuditLogins'),
        ('SecurityAuditPermissions'),
        ('SecurityAuditRoleMembers'),
        ('ServerInventory'),
        ('TempDBContentionHistory'),
        ('WaitStatsHistory')
    ) AS ExpectedTables(name)
    ORDER BY name;

SELECT @TableCount = COUNT(*)
FROM (
    VALUES
        ('AGDatabaseSync'),
        ('AGReplicaHealth'),
        ('AlertConfiguration'),
        ('BackupHistory'),
        ('DatabaseDocumentation'),
        ('DatabaseSizeHistory'),
        ('DuplicateIndexAudit'),
        ('ErrorLogArchive'),
        ('ErrorLogSummary'),
        ('GrowthProjection'),
        ('IndexMaintenanceLog'),
        ('IndexRecommendations'),
        ('JobHistorySummary'),
        ('LoginAudit'),
        ('LoginTransferScript'),
        ('PerfCounters'),
        ('PerformanceBaseline'),
        ('PerformanceVariance'),
        ('QueryStatsSnapshot'),
        ('SecurityAuditDDL'),
        ('SecurityAuditLogins'),
        ('SecurityAuditPermissions'),
        ('SecurityAuditRoleMembers'),
        ('ServerInventory'),
        ('TempDBContentionHistory'),
        ('WaitStatsHistory')
    ) AS ExpectedTables(name)
WHERE OBJECT_ID('dba.' + name, 'U') IS NOT NULL;

PRINT '  Tables found: ' + CAST(@TableCount AS VARCHAR) + ' of 26 expected';
PRINT '';

-- =============================================
-- CHECK 3: Views
-- =============================================
PRINT '--- CHECK 3: Views ---';

DECLARE @ViewCount INT = 0;

SELECT
    name AS ViewName,
    CASE WHEN OBJECT_ID('dba.' + name, 'V') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Status
FROM (
    VALUES
        ('vActiveAlerts'),
        ('vAGDatabaseSync'),
        ('vAGFailoverHistory'),
        ('vAGReplicaHealth'),
        ('vAlertHistory'),
        ('vBackupStatus'),
        ('vDatabaseGrowthTrend'),
        ('vDeadlocks'),
        ('vDiskSpaceRisk'),
        ('vDuplicateIndexes'),
        ('vErrorLogSummary'),
        ('vFailedLogins24Hours'),
        ('vGrowthProjection'),
        ('vIndexMaintenanceSummary'),
        ('vIndexRecommendations'),
        ('vLoginAuditSummary'),
        ('vQueryPerformanceOutliers'),
        ('vRecentErrors'),
        ('vServerInventory'),
        ('vSignificantVariances'),
        ('vTempDBContention'),
        ('vTempDBHealthSummary'),
        ('vUnusedIndexes'),
        ('vWaitStatsCurrent'),
        ('vWaitStatsTrend')
    ) AS ExpectedViews(name)
    ORDER BY name;

SELECT @ViewCount = COUNT(*)
FROM (
    VALUES
        ('vActiveAlerts'),
        ('vAGDatabaseSync'),
        ('vAGFailoverHistory'),
        ('vAGReplicaHealth'),
        ('vAlertHistory'),
        ('vBackupStatus'),
        ('vDatabaseGrowthTrend'),
        ('vDeadlocks'),
        ('vDiskSpaceRisk'),
        ('vDuplicateIndexes'),
        ('vErrorLogSummary'),
        ('vFailedLogins24Hours'),
        ('vGrowthProjection'),
        ('vIndexMaintenanceSummary'),
        ('vIndexRecommendations'),
        ('vLoginAuditSummary'),
        ('vQueryPerformanceOutliers'),
        ('vRecentErrors'),
        ('vServerInventory'),
        ('vSignificantVariances'),
        ('vTempDBContention'),
        ('vTempDBHealthSummary'),
        ('vUnusedIndexes'),
        ('vWaitStatsCurrent'),
        ('vWaitStatsTrend')
    ) AS ExpectedViews(name)
    WHERE OBJECT_ID('dba.' + name, 'V') IS NOT NULL;

PRINT '  Views found: ' + CAST(@ViewCount AS VARCHAR) + ' of 25 expected';
PRINT '';

-- =============================================
-- CHECK 4: Stored Procedures
-- =============================================
PRINT '--- CHECK 4: Stored Procedures ---';

DECLARE @ProcCount INT = 0;

SELECT
    name AS ProcedureName,
    CASE WHEN OBJECT_ID('dba.' + name, 'P') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Status
FROM (
    VALUES
        ('AnalyzeTempDBContention'),
        ('CalculateGrowthProjection'),
        ('CaptureAGHealth'),
        ('CaptureBaseline'),
        ('CaptureDatabaseDocumentation'),
        ('CaptureDatabaseSizes'),
        ('CaptureErrorLog'),
        ('CaptureGrowthData'),
        ('CaptureIndexRecommendations'),
        ('CaptureLoginAudit'),
        ('CaptureLoginsForTransfer'),
        ('CapturePerfCounters'),
        ('CaptureQueryStats'),
        ('CaptureRoleMembership'),
        ('CaptureServerPermissions'),
        ('CaptureTempDBContention'),
        ('CaptureWaitStats'),
        ('CheckAlerts'),
        ('CheckBlockingAlert'),
        ('CompareLogins'),
        ('CompareToBaseline'),
        ('FindDuplicateIndexes'),
        ('GenerateDatabaseUserScript'),
        ('GenerateDocumentation'),
        ('GenerateDropDuplicateScript'),
        ('GenerateDropIndexScript'),
        ('GenerateHTMLHealthReport'),
        ('GenerateLoginTransferScript'),
        ('GenerateQuickReference'),
        ('GenerateWeeklySummary'),
        ('GetIndexSpaceSavings'),
        ('IndexMaintenance'),
        ('LogBackup'),
        ('LogFailedLogin'),
        ('LogLoginEvent'),
        ('MarkDuplicateResolved'),
        ('MarkIndexImplemented'),
        ('PurgeOldData')
    ) AS ExpectedProcs(name)
    ORDER BY name;

SELECT @ProcCount = COUNT(*)
FROM (
    VALUES
        ('AnalyzeTempDBContention'),
        ('CalculateGrowthProjection'),
        ('CaptureAGHealth'),
        ('CaptureBaseline'),
        ('CaptureDatabaseDocumentation'),
        ('CaptureDatabaseSizes'),
        ('CaptureErrorLog'),
        ('CaptureGrowthData'),
        ('CaptureIndexRecommendations'),
        ('CaptureLoginAudit'),
        ('CaptureLoginsForTransfer'),
        ('CapturePerfCounters'),
        ('CaptureQueryStats'),
        ('CaptureRoleMembership'),
        ('CaptureServerPermissions'),
        ('CaptureTempDBContention'),
        ('CaptureWaitStats'),
        ('CheckAlerts'),
        ('CheckBlockingAlert'),
        ('CompareLogins'),
        ('CompareToBaseline'),
        ('FindDuplicateIndexes'),
        ('GenerateDatabaseUserScript'),
        ('GenerateDocumentation'),
        ('GenerateDropDuplicateScript'),
        ('GenerateDropIndexScript'),
        ('GenerateHTMLHealthReport'),
        ('GenerateLoginTransferScript'),
        ('GenerateQuickReference'),
        ('GenerateWeeklySummary'),
        ('GetIndexSpaceSavings'),
        ('IndexMaintenance'),
        ('LogBackup'),
        ('LogFailedLogin'),
        ('LogLoginEvent'),
        ('MarkDuplicateResolved'),
        ('MarkIndexImplemented'),
        ('PurgeOldData')
) AS ExpectedProcs(name)
WHERE OBJECT_ID('dba.' + name, 'P') IS NOT NULL;

PRINT '  Procedures found: ' + CAST(@ProcCount AS VARCHAR) + ' of 38 expected';
PRINT '';

-- =============================================
-- CHECK 5: Functions
-- =============================================
PRINT '--- CHECK 5: Functions ---';

DECLARE @FuncCount INT = 0;

SELECT
    name AS FunctionName,
    CASE WHEN OBJECT_ID('dba.' + name, 'FN') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS Status
FROM (
    VALUES
        ('fn_CalcFragDelta'),
        ('fn_FormatBytes'),
        ('fn_GetBackupChainStatus'),
        ('fn_GetDatabaseAge')
    ) AS ExpectedFuncs(name)
    ORDER BY name;

SELECT @FuncCount = COUNT(*)
FROM (
    VALUES
        ('fn_CalcFragDelta'),
        ('fn_FormatBytes'),
        ('fn_GetBackupChainStatus'),
        ('fn_GetDatabaseAge')
    ) AS ExpectedFuncs(name)
WHERE OBJECT_ID('dba.' + name, 'FN') IS NOT NULL;

PRINT '  Functions found: ' + CAST(@FuncCount AS VARCHAR) + ' of 4 expected';
PRINT '';

-- =============================================
-- CHECK 6: SQL Agent Jobs
-- =============================================
PRINT '--- CHECK 6: SQL Agent Jobs ---';

IF EXISTS (SELECT 1 FROM msdb.dbo.sysdatabases WHERE name = 'DBATools')
BEGIN
    SELECT
        j.name AS JobName,
        CASE WHEN j.enabled = 1 THEN 'Enabled' ELSE 'Disabled' END AS Status,
        j.description
    FROM msdb.dbo.sysjobs j
    WHERE j.name LIKE 'DBATools - %'
       OR j.name LIKE 'DatabaseBackup - %'
       OR j.name LIKE 'DatabaseIntegrityCheck - %'
    ORDER BY j.name;
END
ELSE
BEGIN
    PRINT '  Cannot check jobs - DBATools database not found';
END

PRINT '';

-- =============================================
-- SUMMARY
-- =============================================
PRINT '========================================';
PRINT 'Verification Summary for: ' + @@SERVERNAME;
PRINT '========================================';

-- Database check
IF DB_ID('DBATools') IS NOT NULL
    PRINT '  Database: DBATools [OK]';
ELSE
    PRINT '  Database: DBATools [FAIL]';

-- Table count
IF @TableCount >= 20
    PRINT '  Tables: ' + CAST(@TableCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Tables: ' + CAST(@TableCount AS VARCHAR) + ' [INCOMPLETE]';

-- View count
IF @ViewCount >= 23
    PRINT '  Views: ' + CAST(@ViewCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Views: ' + CAST(@ViewCount AS VARCHAR) + ' [INCOMPLETE]';

-- Procedure count
IF @ProcCount >= 35
    PRINT '  Procedures: ' + CAST(@ProcCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Procedures: ' + CAST(@ProcCount AS VARCHAR) + ' [INCOMPLETE]';

-- Function count
IF @FuncCount = 4
    PRINT '  Functions: ' + CAST(@FuncCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Functions: ' + CAST(@FuncCount AS VARCHAR) + ' [INCOMPLETE]';

PRINT '';
PRINT '========================================';
PRINT 'To run on both servers:';
PRINT '  sqlcmd -S SQL2022 -U zed -P "ZzCIBcUE9eB33n" -i sqlserver/test_dbatools_objects.sql';
PRINT '  sqlcmd -S SQL2025 -U zed -P "ZzCIBcUE9eB33n" -i sqlserver/test_dbatools_objects.sql';
PRINT '========================================';
GO
