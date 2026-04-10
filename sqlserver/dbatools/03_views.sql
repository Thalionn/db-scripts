-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 03_views.sql
-- Purpose: Utility views for DBATools
-- Usage:   Run after 02_procedures.sql for quick diagnostics
-- ============================================================================

USE DBATools;
GO

-- Current wait stats (latest snapshot)
CREATE OR ALTER VIEW dba.vWaitStatsCurrent
AS
SELECT 
    w.ServerName,
    w.CaptureTime,
    w.WaitType,
    w.WaitTimeMs,
    w.SignalWaitTimeMs,
    w.WaitingTasks,
    ROUND(w.WaitTimeMs * 100.0 / NULLIF(SUM(w.WaitTimeMs) OVER(PARTITION BY w.ServerName, w.CaptureTime), 0), 2) AS WaitPercent,
    CASE 
        WHEN w.WaitType LIKE 'PAGEIOLATCH%' THEN 'I/O'
        WHEN w.WaitType LIKE 'LCK_M%' THEN 'Lock'
        WHEN w.WaitType LIKE 'PAGELATCH%' THEN 'Latch'
        WHEN w.WaitType LIKE 'ASYNC%' THEN 'Network'
        WHEN w.WaitType = 'CXPACKET' THEN 'Parallelism'
        WHEN w.WaitType IN ('SOS_SCHEDULER_YIELD', 'THREADPOOL') THEN 'CPU'
        ELSE 'Other'
    END AS Category
FROM dba.WaitStatsHistory w
WHERE w.CaptureTime = (
    SELECT MAX(CaptureTime) 
    FROM dba.WaitStatsHistory 
    WHERE ServerName = w.ServerName
)
AND w.WaitTimeMs > 0;
GO

-- Top wait types trend
CREATE OR ALTER VIEW dba.vWaitStatsTrend
AS
SELECT 
    CAST(w.CaptureTime AS DATE) AS SnapshotDate,
    w.WaitType,
    SUM(w.WaitTimeMs) AS TotalWaitMs,
    COUNT(*) AS SnapshotCount,
    SUM(w.WaitTimeMs) / NULLIF(COUNT(*), 0) AS AvgWaitMs
FROM dba.WaitStatsHistory w
GROUP BY CAST(w.CaptureTime AS DATE), w.WaitType;
GO

-- Backup status summary
CREATE OR ALTER VIEW dba.vBackupStatus
AS
SELECT 
    ServerName,
    DatabaseName,
    BackupType,
    MAX(BackupStart) AS LastBackupStart,
    MAX(BackupFinish) AS LastBackupFinish,
    DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) AS HoursSinceBackup,
    MAX(BackupSizeMB) AS LastBackupSizeMB,
    CASE 
        WHEN DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) > 24 THEN 'OVERDUE'
        WHEN DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) > 12 THEN 'WARNING'
        ELSE 'OK'
    END AS BackupStatus
FROM dba.BackupHistory
GROUP BY ServerName, DatabaseName, BackupType;
GO

-- Database growth trend
CREATE OR ALTER VIEW dba.vDatabaseGrowthTrend
AS
SELECT 
    ServerName,
    DatabaseName,
    CAST(CaptureTime AS DATE) AS SnapshotDate,
    AVG(TotalSizeMB) AS AvgSizeMB,
    AVG(SpaceUsedMB) AS AvgUsedMB,
    AVG(SpaceAvailableMB) AS AvgFreeMB
FROM dba.DatabaseSizeHistory
GROUP BY ServerName, DatabaseName, CAST(CaptureTime AS DATE);
GO

-- Index maintenance summary
CREATE OR ALTER VIEW dba.vIndexMaintenanceSummary
AS
SELECT 
    ServerName,
    DatabaseName,
    TableName,
    IndexName,
    OperationType,
    COUNT(*) AS OperationCount,
    MIN(OperationStart) AS FirstOperation,
    MAX(OperationFinish) AS LastOperation,
    SUM(DurationSeconds) AS TotalDurationSec,
    AVG(FragBefore) AS AvgFragBefore,
    AVG(FragAfter) AS AvgFragAfter,
    SUM(CASE WHEN Status = 'Success' THEN 1 ELSE 0 END) AS SuccessCount,
    SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS FailureCount
FROM dba.IndexMaintenanceLog
GROUP BY ServerName, DatabaseName, TableName, IndexName, OperationType;
GO

-- Login audit summary
CREATE OR ALTER VIEW dba.vLoginAuditSummary
AS
SELECT 
    CAST(LoginTime AS DATE) AS LoginDate,
    LoginName,
    EventType,
    COUNT(*) AS EventCount,
    SUM(CASE WHEN IsSuccessful = 1 THEN 1 ELSE 0 END) AS SuccessfulCount,
    SUM(CASE WHEN IsSuccessful = 0 THEN 1 ELSE 0 END) AS FailedCount
FROM dba.LoginAudit
GROUP BY CAST(LoginTime AS DATE), LoginName, EventType;
GO

-- Failed logins (last 24 hours)
CREATE OR ALTER VIEW dba.vFailedLogins24Hours
AS
SELECT 
    LoginName,
    HostName,
    IPAddress,
    COUNT(*) AS FailedAttempts,
    MIN(LoginTime) AS FirstAttempt,
    MAX(LoginTime) AS LastAttempt,
    DATEDIFF(MINUTE, MAX(LoginTime), GETDATE()) AS MinutesAgo
FROM dba.LoginAudit
WHERE EventType = 'FAILED_LOGIN'
  AND LoginTime > DATEADD(HOUR, -24, GETDATE())
GROUP BY LoginName, HostName, IPAddress
HAVING COUNT(*) >= 3;
GO

-- Query performance outliers
CREATE OR ALTER VIEW dba.vQueryPerformanceOutliers
AS
SELECT TOP 50
    ServerName,
    DatabaseName,
    QueryHash,
    LEFT(QueryText, 200) AS QueryPreview,
    ExecutionCount,
    AvgElapsedMS,
    AvgLogicalReads,
    TotalElapsedMS,
    TotalLogicalReads,
    LastExecutionTime,
    CASE 
        WHEN AvgLogicalReads > 100000 THEN 'High Reads'
        WHEN AvgElapsedMS > 10000 THEN 'High Duration'
        WHEN ExecutionCount > 1000 THEN 'High Frequency'
        ELSE 'Other'
    END AS IssueType
FROM dba.QueryStatsSnapshot
WHERE CaptureTime = (SELECT MAX(CaptureTime) FROM dba.QueryStatsSnapshot)
ORDER BY TotalElapsedMS DESC;
GO

-- Server inventory view
CREATE OR ALTER VIEW dba.vServerInventory
AS
SELECT 
    si.ServerID,
    si.ServerName,
    si.InstanceName,
    si.Environment,
    si.IsActive,
    si.DateAdded,
    si.Notes,
    bs.LastBackupStatus,
    bs.HoursSinceBackup,
    qs.LastCapture AS LastPerfCapture,
    la.FailedLogins24h
FROM dba.ServerInventory si
LEFT JOIN (
    SELECT ServerName, 
           MAX(BackupStatus) AS LastBackupStatus,
           MAX(HoursSinceBackup) AS HoursSinceBackup
    FROM dba.vBackupStatus
    GROUP BY ServerName
) bs ON si.ServerName = bs.ServerName
LEFT JOIN (
    SELECT ServerName, MAX(CaptureTime) AS LastCapture
    FROM dba.PerfCounters GROUP BY ServerName
) qs ON si.ServerName = qs.ServerName
LEFT JOIN (
    SELECT ServerName, COUNT(*) AS FailedLogins24h
    FROM dba.LoginAudit
    WHERE EventType = 'FAILED_LOGIN'
      AND LoginTime > DATEADD(HOUR, -24, GETDATE())
    GROUP BY ServerName
) la ON si.ServerName = la.ServerName;
GO

PRINT 'Views created successfully.';
