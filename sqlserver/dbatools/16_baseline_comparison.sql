-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 16_baseline_comparison.sql
-- Purpose: Compare current performance against historical baseline
-- Usage:   Run weekly for trend analysis; update baseline quarterly
-- Notes:   First run establishes baseline; subsequent runs compare
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.PerformanceBaseline (
    BaselineID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    MetricName NVARCHAR(128),
    MetricValue DECIMAL(18,4),
    MetricType NVARCHAR(50), -- AVG, MIN, MAX, PERCENTILE
    BaselineDate DATE,
    CreatedAt DATETIME DEFAULT GETDATE()
);
GO

CREATE TABLE dba.PerformanceVariance (
    VarianceID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    MetricName NVARCHAR(128),
    CurrentValue DECIMAL(18,4),
    BaselineValue DECIMAL(18,4),
    Variance DECIMAL(18,4),
    VariancePercent DECIMAL(10,2),
    CapturedAt DATETIME DEFAULT GETDATE(),
    AlertTriggered BIT DEFAULT 0
);
GO

-- Capture baseline
CREATE OR ALTER PROCEDURE dba.CaptureBaseline
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DaysForBaseline INT = 30
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @CaptureDate DATE = CAST(GETDATE() AS DATE);
    
    -- Wait stats baseline
    INSERT INTO dba.PerformanceBaseline (ServerName, MetricName, MetricValue, MetricType, BaselineDate)
    SELECT 
        @ServerName,
        'Wait_' + WaitType,
        AVG(WaitTimeMs),
        'AVG',
        @CaptureDate
    FROM dba.WaitStatsHistory
    WHERE CaptureTime >= DATEADD(DAY, -@DaysForBaseline, GETDATE())
      AND ServerName = @ServerName
    GROUP BY WaitType;
    
    -- Perf counters baseline
    INSERT INTO dba.PerformanceBaseline (ServerName, MetricName, MetricValue, MetricType, BaselineDate)
    SELECT 
        @ServerName,
        CounterName,
        AVG(CNTR_VALUE),
        'AVG',
        @CaptureDate
    FROM dba.PerfCounters
    WHERE CaptureTime >= DATEADD(DAY, -@DaysForBaseline, GETDATE())
      AND ServerName = @ServerName
      AND CounterName IN ('Batch Requests/sec', 'Page Life Expectancy', 
                          'SQL Compilations/sec', 'SQL Recompilations/sec',
                          'Page Splits/sec', 'Lazy Writes/sec')
    GROUP BY CounterName;
    
    -- Query performance baseline
    INSERT INTO dba.PerformanceBaseline (ServerName, MetricName, MetricValue, MetricType, BaselineDate)
    SELECT 
        @ServerName,
        'Query_AvgElapsed',
        AVG(AvgElapsedMS),
        'AVG',
        @CaptureDate
    FROM dba.QueryStatsSnapshot
    WHERE CaptureTime >= DATEADD(DAY, -@DaysForBaseline, GETDATE())
      AND ServerName = @ServerName
    GROUP BY DatabaseName;
    
    PRINT 'Baseline captured for ' + @ServerName + ' using last ' + CAST(@DaysForBaseline AS VARCHAR) + ' days.';
    PRINT 'Date: ' + CAST(@CaptureDATE AS VARCHAR);
END
GO

-- Compare to baseline
CREATE OR ALTER PROCEDURE dba.CompareToBaseline
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @VarianceThresholdPct DECIMAL(5,2) = 25.0
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get latest baseline
    DECLARE @LatestBaseline DATE;
    SELECT @LatestBaseline = MAX(BaselineDate) FROM dba.PerformanceBaseline WHERE ServerName = @ServerName;
    
    -- Clear old variance
    DELETE FROM dba.PerformanceVariance WHERE ServerName = @ServerName AND AlertTriggered = 0;
    
    -- Compare wait stats
    INSERT INTO dba.PerformanceVariance (ServerName, MetricName, CurrentValue, BaselineValue, Variance, VariancePercent)
    SELECT 
        @ServerName,
        'Wait_' + w.WaitType,
        w.WaitTimeMs,
        b.MetricValue,
        w.WaitTimeMs - b.MetricValue,
        CASE WHEN b.MetricValue > 0 
             THEN ((w.WaitTimeMs - b.MetricValue) / b.MetricValue) * 100 
             ELSE 0 
        END
    FROM (
        SELECT WaitType, AVG(WaitTimeMs) AS WaitTimeMs
        FROM dba.WaitStatsHistory
        WHERE CaptureTime >= DATEADD(HOUR, -24, GETDATE())
          AND ServerName = @ServerName
        GROUP BY WaitType
    ) w
    JOIN dba.PerformanceBaseline b ON w.WaitType = REPLACE(b.MetricName, 'Wait_', '')
    WHERE b.ServerName = @ServerName
      AND b.BaselineDate = @LatestBaseline
      AND b.MetricType = 'AVG'
      AND ABS(((w.WaitTimeMs - b.MetricValue) / NULLIF(b.MetricValue, 0)) * 100) > @VarianceThresholdPct;
    
    -- Mark significant variances
    UPDATE dba.PerformanceVariance
    SET AlertTriggered = 1
    WHERE ServerName = @ServerName
      AND ABS(VariancePercent) > 50;
    
    -- Return results
    SELECT 
        MetricName,
        CurrentValue,
        BaselineValue,
        Variance,
        VariancePercent,
        CASE
            WHEN VariancePercent > 50 THEN 'SIGNIFICANT INCREASE'
            WHEN VariancePercent > @VarianceThresholdPct THEN 'INCREASE'
            WHEN VariancePercent < -50 THEN 'SIGNIFICANT DECREASE'
            ELSE 'DECREASE'
        END AS Status
    FROM dba.PerformanceVariance
    WHERE ServerName = @ServerName
    ORDER BY ABS(VariancePercent) DESC;
END
GO

CREATE OR ALTER VIEW dba.vSignificantVariances
AS
SELECT 
    v.ServerName,
    v.MetricName,
    v.CurrentValue,
    v.BaselineValue,
    v.Variance,
    v.VariancePercent,
    v.CapturedAt,
    CASE
        WHEN v.VariancePercent > 50 THEN 'CRITICAL'
        WHEN v.VariancePercent > 25 THEN 'WARNING'
        ELSE 'INFO'
    END AS Severity
FROM dba.PerformanceVariance v
WHERE v.CapturedAt >= DATEADD(DAY, -7, GETDATE())
  AND ABS(v.VariancePercent) > 25;
GO

CREATE OR ALTER PROCEDURE dba.GenerateWeeklySummary
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '============================================================';
    PRINT 'WEEKLY PERFORMANCE SUMMARY - ' + @ServerName;
    PRINT 'Report Date: ' + CAST(GETDATE() AS VARCHAR);
    PRINT '============================================================';
    PRINT '';
    
    -- Top waits this week
    PRINT '--- TOP 10 WAIT EVENTS (This Week) ---';
    SELECT TOP 10
        WaitType,
        SUM(WaitTimeMs) AS TotalWaitMs,
        AVG(WaitTimeMs) AS AvgWaitMs,
        COUNT(*) AS Samples
    FROM dba.WaitStatsHistory
    WHERE CaptureTime >= DATEADD(DAY, -7, GETDATE())
      AND ServerName = @ServerName
    GROUP BY WaitType
    ORDER BY TotalWaitMs DESC;
    
    -- Databases needing backups
    PRINT '';
    PRINT '--- BACKUP STATUS ---';
    SELECT 
        DatabaseName,
        BackupType,
        MAX(BackupFinish) AS LastBackup,
        DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) AS HoursSince,
        CASE
            WHEN DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) > 48 THEN 'OVERDUE'
            WHEN DATEDIFF(HOUR, MAX(BackupFinish), GETDATE()) > 24 THEN 'WARNING'
            ELSE 'OK'
        END AS Status
    FROM dba.BackupHistory
    WHERE ServerName = @ServerName
    GROUP BY DatabaseName, BackupType
    ORDER BY HoursSince DESC;
    
    -- Failed logins
    PRINT '';
    PRINT '--- FAILED LOGINS (This Week) ---';
    SELECT 
        LoginName,
        COUNT(*) AS FailedAttempts,
        MIN(LoginTime) AS FirstAttempt,
        MAX(LoginTime) AS LastAttempt,
        HostName
    FROM dba.LoginAudit
    WHERE EventType = 'FAILED_LOGIN'
      AND LoginTime >= DATEADD(DAY, -7, GETDATE())
      AND ServerName = @ServerName
    GROUP BY LoginName, HostName
    HAVING COUNT(*) >= 3
    ORDER BY FailedAttempts DESC;
    
    -- Growth concerns
    PRINT '';
    PRINT '--- GROWTH PROJECTION SUMMARY ---';
    SELECT * FROM dba.vGrowthProjection WHERE Status != 'OK';
    
    -- Index maintenance
    PRINT '';
    PRINT '--- INDEX MAINTENANCE (This Week) ---';
    SELECT 
        DatabaseName,
        OperationType,
        COUNT(*) AS Operations,
        SUM(DurationSeconds) AS TotalDuration,
        SUM(CASE WHEN Status = 'Failed' THEN 1 ELSE 0 END) AS Failures
    FROM dba.IndexMaintenanceLog
    WHERE OperationStart >= DATEADD(DAY, -7, GETDATE())
      AND ServerName = @ServerName
    GROUP BY DatabaseName, OperationType;
    
    PRINT '';
    PRINT '============================================================';
    PRINT 'END OF REPORT';
    PRINT '============================================================';
END
GO

PRINT 'Baseline comparison and weekly summary created.';
PRINT 'Run CaptureBaseline quarterly to update baselines.';
PRINT 'Run CompareToBaseline weekly to identify anomalies.';
PRINT 'Run GenerateWeeklySummary for management reports.';
