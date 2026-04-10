-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 04_functions.sql
-- Purpose: Utility functions for DBATools
-- Usage:   Helper functions for calculations and formatting
-- ============================================================================

USE DBATools;
GO

-- Format bytes to human readable
CREATE OR ALTER FUNCTION dba.fn_FormatBytes
(
    @Bytes BIGINT
)
RETURNS NVARCHAR(50)
AS
BEGIN
    DECLARE @Result NVARCHAR(50);
    
    SELECT @Result = CASE
        WHEN @Bytes >= 1099511627776 THEN CAST(CAST(@Bytes AS DECIMAL(18,2)) / 1099511627776 AS NVARCHAR) + ' TB'
        WHEN @Bytes >= 1073741824 THEN CAST(CAST(@Bytes AS DECIMAL(18,2)) / 1073741824 AS NVARCHAR) + ' GB'
        WHEN @Bytes >= 1048576 THEN CAST(CAST(@Bytes AS DECIMAL(18,2)) / 1048576 AS NVARCHAR) + ' MB'
        WHEN @Bytes >= 1024 THEN CAST(CAST(@Bytes AS DECIMAL(18,2)) / 1024 AS NVARCHAR) + ' KB'
        ELSE CAST(@Bytes AS NVARCHAR) + ' bytes'
    END;
    
    RETURN @Result;
END
GO

-- Calculate database age in days
CREATE OR ALTER FUNCTION dba.fn_GetDatabaseAge
(
    @DatabaseName NVARCHAR(128),
    @ServerName NVARCHAR(128) = @@SERVERNAME
)
RETURNS INT
AS
BEGIN
    DECLARE @OldestBackup DATE;
    
    SELECT TOP 1 @OldestBackup = CAST(BackupStart AS DATE)
    FROM dba.BackupHistory
    WHERE DatabaseName = @DatabaseName
      AND BackupType = 'D'
      AND ServerName = @ServerName
    ORDER BY BackupStart ASC;
    
    RETURN DATEDIFF(DAY, @OldestBackup, GETDATE());
END
GO

-- Get backup chain status
CREATE OR ALTER FUNCTION dba.fn_GetBackupChainStatus
(
    @DatabaseName NVARCHAR(128),
    @ServerName NVARCHAR(128) = @@SERVERNAME
)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @FullBackup DATETIME;
    DECLARE @DiffBackup DATETIME;
    DECLARE @LogBackup DATETIME;
    
    SELECT TOP 1 @FullBackup = BackupStart
    FROM dba.BackupHistory
    WHERE DatabaseName = @DatabaseName
      AND BackupType = 'D'
      AND ServerName = @ServerName
    ORDER BY BackupStart DESC;
    
    SELECT TOP 1 @DiffBackup = BackupStart
    FROM dba.BackupHistory
    WHERE DatabaseName = @DatabaseName
      AND BackupType = 'I'
      AND ServerName = @ServerName
    ORDER BY BackupStart DESC;
    
    SELECT TOP 1 @LogBackup = BackupStart
    FROM dba.BackupHistory
    WHERE DatabaseName = @DatabaseName
      AND BackupType = 'L'
      AND ServerName = @ServerName
    ORDER BY BackupStart DESC;
    
    IF @FullBackup IS NULL
        RETURN 'NO_BACKUP';
    IF @LogBackup IS NULL OR DATEDIFF(MINUTE, @LogBackup, GETDATE()) > 60
        RETURN 'LOG_GAP';
    IF @DiffBackup IS NULL OR DATEDIFF(HOUR, @DiffBackup, GETDATE()) > 24
        RETURN 'NO_DIFF';
    
    RETURN 'OK';
END
GO

-- Calculate fragmentation delta
CREATE OR ALTER FUNCTION dba.fn_CalcFragDelta
(
    @FragBefore DECIMAL(5,2),
    @FragAfter DECIMAL(5,2)
)
RETURNS DECIMAL(5,2)
AS
BEGIN
    RETURN ISNULL(@FragBefore, 0) - ISNULL(@FragAfter, 0);
END
GO

PRINT 'Functions created successfully.';
