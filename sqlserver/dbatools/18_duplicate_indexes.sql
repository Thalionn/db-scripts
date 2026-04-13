-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.DuplicateIndexAudit (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    DatabaseName NVARCHAR(128),
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(256),
    Index1Name NVARCHAR(256),
    Index2Name NVARCHAR(256),
    Index1Columns NVARCHAR(1000),
    Index2Columns NVARCHAR(1000),
    SharedColumns NVARCHAR(1000),
    Index1SizeKB BIGINT,
    Index2SizeKB BIGINT,
    PotentialSavingsKB BIGINT,
    Recommendation NVARCHAR(50),
    IsResolved BIT DEFAULT 0,
    ResolutionDate DATETIME,
    Notes NVARCHAR(MAX),
    INDEX IX_Audit_Capture NONCLUSTERED (CaptureTime, DatabaseName)
);
GO

CREATE OR ALTER PROCEDURE dba.FindDuplicateIndexes
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DatabaseName NVARCHAR(128) = NULL,
    @MinSizeKB INT = 100
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CapTime DATETIME = GETDATE();

    DECLARE db_cursor CURSOR FOR
    SELECT name 
    FROM sys.databases 
    WHERE state_desc = 'ONLINE' 
      AND is_read_only = 0
      AND name NOT IN ('master', 'model', 'msdb', 'tempdb', 'DBATools');

    IF @DatabaseName IS NOT NULL
    BEGIN
        DEALLOCATE db_cursor;
        SET @DBName = @DatabaseName;
        
        SET @SQL = N'
        INSERT INTO DBATools.dba.DuplicateIndexAudit (
            ServerName, DatabaseName, CaptureTime,
            SchemaName, TableName, Index1Name, Index2Name,
            Index1Columns, Index2Columns, SharedColumns,
            Index1SizeKB, Index2SizeKB, PotentialSavingsKB, Recommendation
        )
        SELECT 
            @ServerName,
            @DBName,
            @CapTime,
            s.name,
            t.name,
            i1.name,
            i2.name,
            i1c.columns AS Index1Columns,
            i2c.columns AS Index2Columns,
            i3.shared_cols AS SharedColumns,
            ps1.used_page_count * 8 AS Index1SizeKB,
            ps2.used_page_count * 8 AS Index2SizeKB,
            ps2.used_page_count * 8 AS PotentialSavingsKB,
            CASE 
                WHEN i2.is_primary_key = 1 THEN ''Keep Index2 (PK)'' 
                WHEN i2.is_unique = 1 THEN ''Keep Index2 (Unique)'' 
                ELSE ''DROP Index2'' 
            END
        FROM sys.indexes i1
        JOIN sys.indexes i2 ON i1.object_id = i2.object_id AND i1.index_id < i2.index_id
        JOIN sys.tables t ON i1.object_id = t.object_id
        JOIN sys.schemas s ON t.schema_id = s.schema_id
        JOIN sys.dm_db_partition_stats ps1 ON i1.object_id = ps1.object_id AND i1.index_id = ps1.index_id
        JOIN sys.dm_db_partition_stats ps2 ON i2.object_id = ps2.object_id AND i2.index_id = ps2.index_id
        CROSS APPLY (
            SELECT STRING_AGG(c.name, '', '') WITHIN GROUP (ORDER BY ic.key_ordinal)
            FROM sys.index_columns ic
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i1.object_id AND ic.index_id = i1.index_id AND ic.key_ordinal > 0
        ) i1c(columns)
        CROSS APPLY (
            SELECT STRING_AGG(c.name, '', '') WITHIN GROUP (ORDER BY ic.key_ordinal)
            FROM sys.index_columns ic
            JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
            WHERE ic.object_id = i2.object_id AND ic.index_id = i2.index_id AND ic.key_ordinal > 0
        ) i2c(columns)
        CROSS APPLY (
            SELECT STRING_AGG(col, '', '') WITHIN GROUP (ORDER BY ord)
            FROM (
                SELECT c1.name AS col, 1 AS ord
                FROM sys.index_columns ic1
                JOIN sys.columns c1 ON ic1.object_id = c1.object_id AND ic1.column_id = c1.column_id
                WHERE ic1.object_id = i1.object_id AND ic1.index_id = i1.index_id AND ic1.key_ordinal > 0
                INTERSECT
                SELECT c2.name AS col, 2 AS ord
                FROM sys.index_columns ic2
                JOIN sys.columns c2 ON ic2.object_id = c2.object_id AND ic2.column_id = c2.column_id
                WHERE ic2.object_id = i2.object_id AND ic2.index_id = i2.index_id AND ic2.key_ordinal > 0
            ) shared
        ) i3(shared_cols)
        WHERE i1.is_primary_key = 0
          AND i1.is_unique = 0
          AND i2.is_primary_key = 0
          AND ps2.used_page_count * 8 >= @MinSizeKB
        ORDER BY PotentialSavingsKB DESC;
        ';

        EXEC sp_executesql @SQL, 
            N'@ServerName NVARCHAR(128), @DBName NVARCHAR(128), @CapTime DATETIME, @MinSizeKB INT',
            @ServerName = @ServerName, @DBName = @DBName, @CapTime = @CapTime, @MinSizeKB = @MinSizeKB;
    END
    ELSE
    BEGIN
        OPEN db_cursor;
        FETCH NEXT FROM db_cursor INTO @DBName;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @SQL = N'
            INSERT INTO DBATools.dba.DuplicateIndexAudit (
                ServerName, DatabaseName, CaptureTime,
                SchemaName, TableName, Index1Name, Index2Name,
                Index1Columns, Index2Columns, SharedColumns,
                Index1SizeKB, Index2SizeKB, PotentialSavingsKB, Recommendation
            )
            SELECT 
                @ServerName,
                @DBName,
                @CapTime,
                s.name,
                t.name,
                i1.name,
                i2.name,
                i1c.columns AS Index1Columns,
                i2c.columns AS Index2Columns,
                i3.shared_cols AS SharedColumns,
                ps1.used_page_count * 8 AS Index1SizeKB,
                ps2.used_page_count * 8 AS Index2SizeKB,
                ps2.used_page_count * 8 AS PotentialSavingsKB,
                CASE 
                    WHEN i2.is_primary_key = 1 THEN ''Keep Index2 (PK)'' 
                    WHEN i2.is_unique = 1 THEN ''Keep Index2 (Unique)'' 
                    ELSE ''DROP Index2'' 
                END
            FROM sys.indexes i1
            JOIN sys.indexes i2 ON i1.object_id = i2.object_id AND i1.index_id < i2.index_id
            JOIN sys.tables t ON i1.object_id = t.object_id
            JOIN sys.schemas s ON t.schema_id = s.schema_id
            JOIN sys.dm_db_partition_stats ps1 ON i1.object_id = ps1.object_id AND i1.index_id = ps1.index_id
            JOIN sys.dm_db_partition_stats ps2 ON i2.object_id = ps2.object_id AND i2.index_id = ps2.index_id
            CROSS APPLY (
                SELECT STRING_AGG(c.name, '', '') WITHIN GROUP (ORDER BY ic.key_ordinal)
                FROM sys.index_columns ic
                JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i1.object_id AND ic.index_id = i1.index_id AND ic.key_ordinal > 0
            ) i1c(columns)
            CROSS APPLY (
                SELECT STRING_AGG(c.name, '', '') WITHIN GROUP (ORDER BY ic.key_ordinal)
                FROM sys.index_columns ic
                JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
                WHERE ic.object_id = i2.object_id AND ic.index_id = i2.index_id AND ic.key_ordinal > 0
            ) i2c(columns)
            CROSS APPLY (
                SELECT STRING_AGG(col, '', '') WITHIN GROUP (ORDER BY ord)
                FROM (
                    SELECT c1.name AS col, 1 AS ord
                    FROM sys.index_columns ic1
                    JOIN sys.columns c1 ON ic1.object_id = c1.object_id AND ic1.column_id = c1.column_id
                    WHERE ic1.object_id = i1.object_id AND ic1.index_id = i1.index_id AND ic1.key_ordinal > 0
                    INTERSECT
                    SELECT c2.name AS col, 2 AS ord
                    FROM sys.index_columns ic2
                    JOIN sys.columns c2 ON ic2.object_id = c2.object_id AND ic2.column_id = c2.column_id
                    WHERE ic2.object_id = i2.object_id AND ic2.index_id = i2.index_id AND ic2.key_ordinal > 0
                ) shared
            ) i3(shared_cols)
            WHERE i1.is_primary_key = 0
              AND i1.is_unique = 0
              AND i2.is_primary_key = 0
              AND ps2.used_page_count * 8 >= @MinSizeKB
            ORDER BY PotentialSavingsKB DESC;
            ';

            BEGIN TRY
                EXEC sp_executesql @SQL, 
                    N'@ServerName NVARCHAR(128), @DBName NVARCHAR(128), @CapTime DATETIME, @MinSizeKB INT',
                    @ServerName = @ServerName, @DBName = @DBName, @CapTime = @CapTime, @MinSizeKB = @MinSizeKB;
            END TRY
            BEGIN CATCH
                PRINT 'Error processing ' + @DBName + ': ' + ERROR_MESSAGE();
            END CATCH

            FETCH NEXT FROM db_cursor INTO @DBName;
        END

        CLOSE db_cursor;
        DEALLOCATE db_cursor;
    END

    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS DuplicatesFound;
END
GO

CREATE OR ALTER VIEW dba.vDuplicateIndexes
AS
SELECT 
    AuditID,
    ServerName,
    CaptureTime,
    DatabaseName,
    SchemaName,
    TableName,
    Index1Name,
    Index2Name,
    Index1Columns,
    Index2Columns,
    Index1SizeKB,
    Index2SizeKB,
    PotentialSavingsKB,
    Recommendation,
    IsResolved,
    Notes
FROM dba.DuplicateIndexAudit
WHERE IsResolved = 0
  AND CaptureTime >= DATEADD(DAY, -7, GETDATE())
ORDER BY PotentialSavingsKB DESC;
GO

CREATE OR ALTER PROCEDURE dba.GenerateDropDuplicateScript
    @AuditID BIGINT = NULL,
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @AuditID IS NOT NULL
    BEGIN
        SELECT 
            'USE [' + DatabaseName + '];' + CHAR(13) + CHAR(10) +
            'DROP INDEX [' + Index2Name + '] ON [' + SchemaName + '].[' + TableName + '];' AS DropScript,
            DatabaseName,
            SchemaName + '.' + TableName AS TableName,
            Index2Name AS IndexToDrop,
            Index2SizeKB AS SpaceSavedKB,
            Recommendation
        FROM dba.DuplicateIndexAudit
        WHERE AuditID = @AuditID AND IsResolved = 0;
    END
    ELSE
    BEGIN
        SELECT 
            'USE [' + DatabaseName + '];' + CHAR(13) + CHAR(10) +
            'DROP INDEX [' + Index2Name + '] ON [' + SchemaName + '].[' + TableName + '];' AS DropScript,
            DatabaseName,
            SchemaName + '.' + TableName AS TableName,
            Index2Name AS IndexToDrop,
            Index2SizeKB AS SpaceSavedKB,
            Recommendation
        FROM dba.DuplicateIndexAudit
        WHERE IsResolved = 0
          AND CaptureTime >= DATEADD(DAY, -7, GETDATE())
        ORDER BY PotentialSavingsKB DESC;
    END;
END
GO

CREATE OR ALTER PROCEDURE dba.MarkDuplicateResolved
    @AuditID BIGINT,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE dba.DuplicateIndexAudit
    SET IsResolved = 1,
        ResolutionDate = GETDATE(),
        Notes = @Notes
    WHERE AuditID = @AuditID;

    SELECT 'Marked as resolved' AS Status, @AuditID AS AuditID;
END
GO

CREATE OR ALTER PROCEDURE dba.GetIndexSpaceSavings
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName NVARCHAR(128) = COALESCE(@DatabaseName, DB_NAME());

    SELECT 
        DatabaseName,
        SUM(PotentialSavingsKB) AS TotalPotentialSavingsKB,
        COUNT(*) AS DuplicatePairs,
        SUM(CASE WHEN Recommendation = 'DROP Index2' THEN 1 ELSE 0 END) AS Actionable
    FROM dba.DuplicateIndexAudit
    WHERE IsResolved = 0
      AND CaptureTime >= DATEADD(DAY, -30, GETDATE())
      AND (@DBName IS NULL OR DatabaseName = @DBName)
    GROUP BY DatabaseName
    ORDER BY TotalPotentialSavingsKB DESC;
END
GO

PRINT 'Duplicate index detection created.';
PRINT 'Usage:';
PRINT '  EXEC dba.FindDuplicateIndexes; -- All databases';
PRINT '  EXEC dba.FindDuplicateIndexes @DatabaseName = ''YourDB''; -- Single DB';
PRINT '  SELECT * FROM dba.vDuplicateIndexes; -- Review findings';
PRINT '  EXEC dba.GenerateDropDuplicateScript; -- Get DROP scripts';
PRINT '  EXEC dba.MarkDuplicateResolved @AuditID = 1, @Notes = ''Dropped manually'';';
