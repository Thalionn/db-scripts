-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.ErrorLogArchive (
    LogID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    ArchiveNum INT,
    LogDate DATETIME,
    ProcessInfo NVARCHAR(100),
    LogText NVARCHAR(MAX),
    Severity INT,
    LogType NVARCHAR(20), -- ERROR, WARNING, INFO, Deadlock
    IsProcessed BIT DEFAULT 0,
    ProcessedDate DATETIME,
    INDEX IX_ErrorLog_Date NONCLUSTERED (LogDate),
    INDEX IX_ErrorLog_Type NONCLUSTERED (LogType),
    INDEX IX_ErrorLog_Severity NONCLUSTERED (Severity)
);
GO

CREATE TABLE dba.ErrorLogSummary (
    SummaryID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureDate DATE,
    ErrorType NVARCHAR(50),
    ErrorCount INT,
    FirstOccurrence DATETIME,
    LastOccurrence DATETIME,
    SampleMessage NVARCHAR(500),
    Severity INT,
    INDEX IX_ErrorSummary_Date NONCLUSTERED (CaptureDate, ErrorType)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureErrorLog
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DaysToCapture INT = 7,
    @ErrorSeverities NVARCHAR(50) = '17,18,19,20,21,22,23,24,25'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ArchiveNum INT;
    DECLARE @LogDate DATETIME;
    DECLARE @ProcessInfo NVARCHAR(100);
    DECLARE @LogText NVARCHAR(MAX);
    DECLARE @Severity INT;
    DECLARE @LogType NVARCHAR(20);
    
    DECLARE error_cursor CURSOR FOR
    SELECT 
        LogDate,
        LEFT(ProcessInfo, 100),
        Text,
        CASE 
            WHEN Text LIKE '%deadlock%' THEN 'Deadlock'
            WHEN Text LIKE '%error%' THEN 'ERROR'
            WHEN Text LIKE '%warning%' OR Text LIKE '%warn%' THEN 'WARNING'
            ELSE 'INFO'
        END
    FROM sys.fn_errorlog_extension(NULL, NULL)
    WHERE LogDate >= DATEADD(DAY, -@DaysToCapture, GETDATE())
      AND (
          Text LIKE '%error%'
          OR Text LIKE '%failed%'
          OR Text LIKE '%deadlock%'
          OR Text LIKE '%corrupt%'
          OR Text LIKE '%failover%'
          OR Text LIKE '%suspect%'
          OR Text LIKE '%cannot%'
          OR Text LIKE '%could not%'
      );
    
    OPEN error_cursor;
    FETCH NEXT FROM error_cursor INTO @LogDate, @ProcessInfo, @LogText, @LogType;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Determine severity from text
        SET @Severity = CASE
            WHEN @LogText LIKE '%severity 17%' THEN 17
            WHEN @LogText LIKE '%severity 18%' THEN 18
            WHEN @LogText LIKE '%severity 19%' THEN 19
            WHEN @LogText LIKE '%severity 2[0-4]%' THEN 20
            WHEN @LogText LIKE '%severity 25%' THEN 25
            WHEN @LogType = 'ERROR' THEN 16
            ELSE 10
        END;
        
        INSERT INTO dba.ErrorLogArchive (
            ServerName, ArchiveNum, LogDate, ProcessInfo, LogText, Severity, LogType
        )
        VALUES (
            @ServerName, ISNULL(@ArchiveNum, 0), @LogDate, @ProcessInfo, @LogText, @Severity, @LogType
        );
        
        FETCH NEXT FROM error_cursor INTO @LogDate, @ProcessInfo, @LogText, @LogType;
    END
    
    CLOSE error_cursor;
    DEALLOCATE error_cursor;
    
    -- Update summary
    INSERT INTO dba.ErrorLogSummary (
        ServerName, CaptureDate, ErrorType, ErrorCount,
        FirstOccurrence, LastOccurrence, SampleMessage, Severity
    )
    SELECT 
        @ServerName,
        CAST(GETDATE() AS DATE),
        LogType,
        COUNT(*),
        MIN(LogDate),
        MAX(LogDate),
        LEFT(MIN(LogText), 500),
        MAX(Severity)
    FROM dba.ErrorLogArchive
    WHERE ServerName = @ServerName
      AND CAST(LogDate AS DATE) = CAST(GETDATE() AS DATE)
      AND IsProcessed = 0
    GROUP BY LogType;
    
    -- Mark as processed
    UPDATE dba.ErrorLogArchive
    SET IsProcessed = 1, ProcessedDate = GETDATE()
    WHERE ServerName = @ServerName
      AND IsProcessed = 0;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

CREATE OR ALTER VIEW dba.vRecentErrors
AS
SELECT TOP 100
    ServerName,
    LogDate,
    ProcessInfo,
    LogText,
    Severity,
    LogType,
    CASE 
        WHEN Severity >= 20 THEN 'CRITICAL'
        WHEN Severity >= 17 THEN 'HIGH'
        WHEN Severity >= 10 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Priority
FROM dba.ErrorLogArchive
WHERE Severity >= 10
  AND LogDate >= DATEADD(HOUR, -24, GETDATE())
ORDER BY LogDate DESC, Severity DESC;
GO

CREATE OR ALTER VIEW dba.vDeadlocks
AS
SELECT 
    ServerName,
    LogDate,
    LEFT(LogText, 2000) AS DeadlockSnippet
FROM dba.ErrorLogArchive
WHERE LogType = 'Deadlock'
  AND LogDate >= DATEADD(DAY, -7, GETDATE())
ORDER BY LogDate DESC;
GO

CREATE OR ALTER VIEW dba.vErrorLogSummary
AS
SELECT 
    ServerName,
    CAST(LogDate AS DATE) AS ErrorDate,
    LogType,
    Severity,
    COUNT(*) AS ErrorCount,
    MIN(LogDate) AS FirstError,
    MAX(LogDate) AS LastError
FROM dba.ErrorLogArchive
GROUP BY ServerName, CAST(LogDate AS DATE), LogType, Severity
HAVING COUNT(*) > 0;
GO

PRINT 'Error log parser tables and procedures created.';
