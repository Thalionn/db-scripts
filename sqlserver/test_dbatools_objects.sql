-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- DBATools Objects Verification Script
-- Verifies all DBATools database objects are properly installed
-- Run this on both SQL2022 and SQL2025 servers
-- ============================================================================

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
        ('ServerInventory'),
        ('LoginAudit'),
        ('WaitStatsHistory'),
        ('PerfCounters'),
        ('DatabaseSizeHistory'),
        ('BackupHistory'),
        ('IndexMaintenanceLog'),
        ('JobHistorySummary'),
        ('QueryStatsSnapshot'),
        ('SecurityAuditLogins'),
        ('SecurityAuditPermissions'),
        ('SecurityAuditDDL'),
        ('ErrorLogArchive'),
        ('ErrorLogSummary'),
        ('AlertConfiguration'),
        ('GrowthProjection'),
        ('PerformanceBaseline'),
        ('PerformanceVariance'),
        ('DatabaseDocumentation'),
        ('DuplicateIndexAudit'),
        ('TempDBContentionHistory'),
        ('AGReplicaHealth'),
        ('AGDatabaseSync')
) AS ExpectedTables(name)
ORDER BY name;

SELECT @TableCount = COUNT(*)
FROM (
    VALUES
        ('ServerInventory'),
        ('LoginAudit'),
        ('WaitStatsHistory'),
        ('PerfCounters'),
        ('DatabaseSizeHistory'),
        ('BackupHistory'),
        ('IndexMaintenanceLog'),
        ('JobHistorySummary'),
        ('QueryStatsSnapshot'),
        ('SecurityAuditLogins'),
        ('SecurityAuditPermissions'),
        ('SecurityAuditDDL'),
        ('ErrorLogArchive'),
        ('ErrorLogSummary'),
        ('AlertConfiguration'),
        ('GrowthProjection'),
        ('PerformanceBaseline'),
        ('PerformanceVariance'),
        ('DatabaseDocumentation'),
        ('DuplicateIndexAudit'),
        ('TempDBContentionHistory'),
        ('AGReplicaHealth'),
        ('AGDatabaseSync')
) AS ExpectedTables(name)
WHERE OBJECT_ID('dba.' + name, 'U') IS NOT NULL;

PRINT '  Tables found: ' + CAST(@TableCount AS VARCHAR) + ' of 21 expected';
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
        ('vWaitStatsCurrent'),
        ('vWaitStatsTrend'),
        ('vBackupStatus'),
        ('vFailedLogins24Hours'),
        ('vQueryPerformanceOutliers'),
        ('vGrowthProjection'),
        ('vDiskSpaceRisk'),
        ('vTempDBContention'),
        ('vTempDBHealthSummary'),
        ('vAGReplicaHealth'),
        ('vAGDatabaseSync'),
        ('vAGFailoverHistory'),
        ('vBackupStatus'),
        ('vFailedLogins24Hours'),
        ('vQueryPerformanceOutliers'),
        ('vRecentErrors'),
        ('vServerInventory'),
        ('vAlertHistory'),
        ('vIndexRecommendations'),
        ('vUnusedIndexes'),
        ('vDuplicateIndexes')
) AS ExpectedViews(name)
ORDER BY name;

SELECT @ViewCount = COUNT(*)
FROM (
    VALUES
        ('vWaitStatsCurrent'),
        ('vWaitStatsTrend'),
        ('vBackupStatus'),
        ('vFailedLogins24Hours'),
        ('vQueryPerformanceOutliers'),
        ('vGrowthProjection'),
        ('vDiskSpaceRisk'),
        ('vTempDBContention'),
        ('vTempDBHealthSummary'),
        ('vAGReplicaHealth'),
        ('vAGDatabaseSync'),
        ('vAGFailoverHistory'),
        ('vBackupStatus'),
        ('vFailedLogins24Hours'),
        ('vQueryPerformanceOutliers'),
        ('vRecentErrors'),
        ('vServerInventory'),
        ('vAlertHistory'),
        ('vIndexRecommendations'),
        ('vUnusedIndexes'),
        ('vDuplicateIndexes')
) AS ExpectedViews(name)
WHERE OBJECT_ID('dba.' + name, 'V') IS NOT NULL;

PRINT '  Views found: ' + CAST(@ViewCount AS VARCHAR) + ' expected (check log for full list)';
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
        ('CaptureWaitStats'),
        ('CapturePerfCounters'),
        ('CaptureDatabaseSizes'),
        ('CaptureQueryStats'),
        ('PurgeOldData'),
        ('CaptureLoginAudit'),
        ('CaptureRoleMembership'),
        ('CaptureServerPermissions'),
        ('CaptureAGHealth'),
        ('CaptureTempDBContention'),
        ('CaptureErrorLog'),
        ('CheckAlerts'),
        ('CheckBlockingAlert'),
        ('CalculateGrowthProjection'),
        ('CaptureBaseline'),
        ('CompareToBaseline'),
        ('GenerateWeeklySummary'),
        ('CaptureDatabaseDocumentation'),
        ('GenerateDocumentation'),
        ('GenerateQuickReference'),
        ('FindDuplicateIndexes'),
        ('GenerateDropDuplicateScript'),
        ('MarkDuplicateResolved'),
        ('CaptureLoginsForTransfer'),
        ('GenerateLoginTransferScript'),
        ('GenerateDatabaseUserScript'),
        ('AnalyzeTempDBContention'),
        ('GenerateHTMLHealthReport')
) AS ExpectedProcs(name)
ORDER BY name;

SELECT @ProcCount = COUNT(*)
FROM (
    VALUES
        ('CaptureWaitStats'),
        ('CapturePerfCounters'),
        ('CaptureDatabaseSizes'),
        ('CaptureQueryStats'),
        ('PurgeOldData'),
        ('CaptureLoginAudit'),
        ('CaptureRoleMembership'),
        ('CaptureServerPermissions'),
        ('CaptureAGHealth'),
        ('CaptureTempDBContention'),
        ('CaptureErrorLog'),
        ('CheckAlerts'),
        ('CheckBlockingAlert'),
        ('CalculateGrowthProjection'),
        ('CaptureBaseline'),
        ('CompareToBaseline'),
        ('GenerateWeeklySummary'),
        ('CaptureDatabaseDocumentation'),
        ('GenerateDocumentation'),
        ('GenerateQuickReference'),
        ('FindDuplicateIndexes'),
        ('GenerateDropDuplicateScript'),
        ('MarkDuplicateResolved'),
        ('CaptureLoginsForTransfer'),
        ('GenerateLoginTransferScript'),
        ('GenerateDatabaseUserScript'),
        ('AnalyzeTempDBContention'),
        ('GenerateHTMLHealthReport')
) AS ExpectedProcs(name)
WHERE OBJECT_ID('dba.' + name, 'P') IS NOT NULL;

PRINT '  Procedures found: ' + CAST(@ProcCount AS VARCHAR) + ' expected (check log for full list)';
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
        ('fn_CalcDateDiff'),
        ('fn_GetBackupStatus'),
        ('fn_CalcFragDelta')
) AS ExpectedFuncs(name)
ORDER BY name;

SELECT @FuncCount = COUNT(*)
FROM (
    VALUES
        ('fn_CalcDateDiff'),
        ('fn_GetBackupStatus'),
        ('fn_CalcFragDelta')
) AS ExpectedFuncs(name)
WHERE OBJECT_ID('dba.' + name, 'FN') IS NOT NULL;

PRINT '  Functions found: ' + CAST(@FuncCount AS VARCHAR) + ' of 3 expected';
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
IF @ViewCount >= 15
    PRINT '  Views: ' + CAST(@ViewCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Views: ' + CAST(@ViewCount AS VARCHAR) + ' [INCOMPLETE]';

-- Procedure count
IF @ProcCount >= 25
    PRINT '  Procedures: ' + CAST(@ProcCount AS VARCHAR) + ' [OK]';
ELSE
    PRINT '  Procedures: ' + CAST(@ProcCount AS VARCHAR) + ' [INCOMPLETE]';

-- Function count
IF @FuncCount = 3
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
