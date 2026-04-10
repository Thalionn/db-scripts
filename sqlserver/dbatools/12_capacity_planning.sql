-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 12_capacity_planning.sql
-- Purpose: Database growth projection and capacity planning
-- Usage:   Run ad-hoc or schedule weekly for reporting
-- Notes:   Helps predict when databases will run out of space
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.GrowthProjection (
    ProjectionID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    CaptureDate DATE,
    CurrentSizeMB BIGINT,
    DailyGrowthMB DECIMAL(10,2),
    DaysToExhaustion INT,
    ProjectedDate DATE,
    FileName NVARCHAR(256),
    FileMaxSizeMB BIGINT,
    FileFreeSpaceMB BIGINT,
    ConfidenceLevel NVARCHAR(20)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureGrowthData
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.DatabaseSizeHistory (ServerName, DatabaseName, DataFileSizeMB, LogFileSizeMB, SpaceUsedMB, SpaceAvailableMB)
    SELECT 
        @ServerName,
        d.name,
        CAST(SUM(CASE WHEN mf.type = 0 THEN mf.size / 128.0 ELSE 0 END) AS BIGINT),
        CAST(SUM(CASE WHEN mf.type = 1 THEN mf.size / 128.0 ELSE 0 END) AS BIGINT),
        CAST(SUM(FILEPROPERTY(mf.name, 'SpaceUsed') / 128.0) AS BIGINT),
        CAST(SUM(mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS BIGINT)
    FROM sys.master_files mf
    JOIN sys.databases d ON mf.database_id = d.database_id
    WHERE d.state_desc = 'ONLINE'
      AND d.name NOT IN ('DBATools')
    GROUP BY d.name;
END
GO

CREATE OR ALTER PROCEDURE dba.CalculateGrowthProjection
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DaysToAnalyze INT = 30,
    @ProjectionDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @GrowthData TABLE (
        DatabaseName NVARCHAR(128),
        FirstSizeMB BIGINT,
        LastSizeMB BIGINT,
        FirstDate DATE,
        LastDate DATE,
        GrowthRateMB DECIMAL(10,2),
        DaysBetween INT
    );
    
    -- Calculate growth rate from historical data
    INSERT INTO @GrowthData
    SELECT 
        DatabaseName,
        MIN(TotalSizeMB) AS FirstSizeMB,
        MAX(TotalSizeMB) AS LastSizeMB,
        MIN(CAST(CaptureTime AS DATE)) AS FirstDate,
        MAX(CAST(CaptureTime AS DATE)) AS LastDate,
        CAST((MAX(TotalSizeMB) - MIN(TotalSizeMB)) AS DECIMAL(10,2)) / NULLIF(DATEDIFF(DAY, MIN(CAST(CaptureTime AS DATE)), MAX(CAST(CaptureTime AS DATE))), 0) AS GrowthRateMB,
        DATEDIFF(DAY, MIN(CAST(CaptureTime AS DATE)), MAX(CAST(CaptureTime AS DATE))) AS DaysBetween
    FROM dba.DatabaseSizeHistory
    WHERE ServerName = @ServerName
      AND CaptureTime >= DATEADD(DAY, -@DaysToAnalyze, GETDATE())
    GROUP BY DatabaseName
    HAVING MIN(TotalSizeMB) < MAX(TotalSizeMB);
    
    -- Clear old projections
    DELETE FROM dba.GrowthProjection WHERE ServerName = @ServerName;
    
    -- Calculate projections
    INSERT INTO dba.GrowthProjection (
        ServerName, DatabaseName, CaptureDate, CurrentSizeMB, 
        DailyGrowthMB, DaysToExhaustion, ProjectedDate,
        ConfidenceLevel
    )
    SELECT 
        @ServerName,
        gd.DatabaseName,
        CAST(GETDATE() AS DATE),
        gd.LastSizeMB,
        gd.GrowthRateMB,
        CASE 
            WHEN gd.GrowthRateMB > 0 THEN CAST(gd.LastSizeMB / gd.GrowthRateMB AS INT)
            ELSE NULL
        END,
        CASE 
            WHEN gd.GrowthRateMB > 0 
            THEN DATEADD(DAY, CAST(gd.LastSizeMB / gd.GrowthRateMB AS INT), CAST(GETDATE() AS DATE))
            ELSE NULL
        END,
        CASE 
            WHEN gd.DaysBetween >= 30 THEN 'HIGH'
            WHEN gd.DaysBetween >= 14 THEN 'MEDIUM'
            ELSE 'LOW'
        END
    FROM @GrowthData gd;
    
    -- Add file-level detail
    INSERT INTO dba.GrowthProjection (
        ServerName, DatabaseName, CaptureDate, CurrentSizeMB,
        FileName, FileMaxSizeMB, FileFreeSpaceMB, ConfidenceLevel
    )
    SELECT 
        @ServerName,
        d.name,
        CAST(GETDATE() AS DATE),
        CAST(mf.size / 128.0 AS BIGINT),
        mf.name,
        CASE WHEN mf.max_size = -1 THEN NULL ELSE CAST(mf.max_size / 128.0 AS BIGINT) END,
        CAST((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS BIGINT),
        'FILE_DETAIL'
    FROM sys.master_files mf
    JOIN sys.databases d ON mf.database_id = d.database_id
    WHERE d.state_desc = 'ONLINE'
      AND mf.max_size > 0
      AND d.name NOT IN ('tempdb', 'model');
    
    -- Return results
    SELECT 
        ServerName,
        DatabaseName,
        CurrentSizeMB,
        DailyGrowthMB,
        DaysToExhaustion,
        ProjectedDate,
        ConfidenceLevel,
        CASE
            WHEN DaysToExhaustion <= 7 THEN 'CRITICAL'
            WHEN DaysToExhaustion <= 30 THEN 'WARNING'
            ELSE 'OK'
        END AS Status
    FROM dba.GrowthProjection
    WHERE ConfidenceLevel != 'FILE_DETAIL'
    ORDER BY DaysToExhaustion ASC NULLS LAST;
END
GO

CREATE OR ALTER VIEW dba.vGrowthProjection
AS
SELECT 
    ServerName,
    DatabaseName,
    CurrentSizeMB,
    DailyGrowthMB,
    DaysToExhaustion,
    ProjectedDate,
    ConfidenceLevel,
    CASE
        WHEN DaysToExhaustion <= 7 THEN 'CRITICAL'
        WHEN DaysToExhaustion <= 30 THEN 'WARNING'
        WHEN DaysToExhaustion <= 60 THEN 'MONITOR'
        ELSE 'OK'
    END AS Status,
    CASE
        WHEN DailyGrowthMB > 1024 THEN CAST(DailyGrowthMB / 1024 AS VARCHAR) + ' GB/day'
        ELSE CAST(DailyGrowthMB AS VARCHAR) + ' MB/day'
    END AS GrowthRateFormatted
FROM dba.GrowthProjection
WHERE ConfidenceLevel != 'FILE_DETAIL';
GO

CREATE OR ALTER VIEW dba.vDiskSpaceRisk
AS
SELECT 
    ServerName,
    DatabaseName,
    FileName,
    FileFreeSpaceMB,
    FileMaxSizeMB,
    CAST(FileFreeSpaceMB / 1024.0 AS DECIMAL(10,2)) AS FreeSpaceGB,
    CAST((FileMaxSizeMB - FileFreeSpaceMB) / 1024.0 AS DECIMAL(10,2)) AS UsedSpaceGB,
    CAST(FileFreeSpaceMB * 100.0 / NULLIF(FileMaxSizeMB, 0) AS DECIMAL(5,2)) AS FreeSpacePercent,
    CASE 
        WHEN FileFreeSpaceMB * 100.0 / NULLIF(FileMaxSizeMB, 0) < 10 THEN 'CRITICAL'
        WHEN FileFreeSpaceMB * 100.0 / NULLIF(FileMaxSizeMB, 0) < 20 THEN 'WARNING'
        ELSE 'OK'
    END AS Status
FROM dba.GrowthProjection
WHERE ConfidenceLevel = 'FILE_DETAIL'
  AND FileMaxSizeMB IS NOT NULL;
GO

PRINT 'Capacity planning tables and procedures created.';
PRINT 'Run CalculateGrowthProjection weekly to track growth trends.';
