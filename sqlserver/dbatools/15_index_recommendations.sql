-- ============================================================================
-- Script: 15_index_recommendations.sql
-- Purpose: Generate missing/high-value index recommendations
-- Usage:   Run weekly during off-peak; review before implementing
-- Notes:   Based on missing index DMVs and query statistics
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.IndexRecommendations (
    RecID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    DatabaseName NVARCHAR(128),
    SchemaName NVARCHAR(128),
    TableName NVARCHAR(256),
    IndexName NVARCHAR(256),
    IndexColumns NVARCHAR(1000),
    IncludedColumns NVARCHAR(1000),
    EstimatedImpact DECIMAL(10,2),
    AvgUserSeekSeconds DECIMAL(10,2),
    UserSeeks BIGINT,
    AvgUserScans DECIMAL(10,2),
    UserScans BIGINT,
    Statement NVARCHAR(MAX),
    CreateStatement NVARCHAR(MAX),
    IsImplemented BIT DEFAULT 0,
    ImplementedDate DATETIME,
    Notes NVARCHAR(MAX),
    INDEX IX_Recs_Capture NONCLUSTERED (CaptureTime, DatabaseName),
    INDEX IX_Recs_Implemented NONCLUSTERED (IsImplemented, CaptureTime)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureIndexRecommendations
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @DBName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);
    
    DECLARE db_cursor CURSOR FOR
    SELECT name 
    FROM sys.databases 
    WHERE state_desc = 'ONLINE' 
      AND is_read_only = 0
      AND name NOT IN ('master', 'model', 'msdb', 'tempdb', 'DBATools');
    
    OPEN db_cursor;
    FETCH NEXT FROM db_cursor INTO @DBName;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @SQL = 'USE [' + @DBName + '];
        
        INSERT INTO DBATools.dba.IndexRecommendations (
            ServerName, DatabaseName, SchemaName, TableName, IndexName,
            IndexColumns, IncludedColumns, EstimatedImpact,
            AvgUserSeekSeconds, UserSeeks, Statement, CreateStatement
        )
        SELECT 
            ''' + @ServerName + ''',
            ''' + @DBName + ''',
            ISNULL(mid.schema_name, ''dbo''),
            OBJECT_NAME(mid.object_id, DB_ID(''' + @DBName + ''')),
            ''IX_'' + OBJECT_NAME(mid.object_id, DB_ID(''' + @DBName + ''')) + ''_'' + REPLACE(REPLACE(mid.equality_columns, ''['', ''''), '']'', '''') + ''_'' + REPLACE(REPLACE(mid.inequality_columns, ''['', ''''), '']'', ''''),
            mid.equality_columns + ISNULL('', '' + mid.inequality_columns, ''''),
            mid.included_columns,
            mig.avg_user_impact,
            mig.avg_total_user_cost,
            mid.user_seeks,
            mid.statement,
            ''CREATE INDEX [IX_'' + OBJECT_NAME(mid.object_id, DB_ID(''' + @DBName + ''')) + ''_'' + CAST(mid.index_handle AS VARCHAR) + ''] ON ['' + ISNULL(mid.schema_name, ''dbo'') + ''].['' + OBJECT_NAME(mid.object_id, DB_ID(''' + @DBName + ''')) + ''] ('' + mid.equality_columns + ISNULL('', '' + mid.inequality_columns, '''') + '')'' + ISNULL('' INCLUDE ('' + mid.included_columns + '');'', '';'')
        FROM sys.dm_db_missing_index_details mid
        JOIN sys.dm_db_missing_index_groups mig ON mid.index_handle = mig.index_handle
        JOIN sys.dm_db_missing_index_group_stats migs ON mig.index_group_handle = migs.group_handle
        WHERE mid.database_id = DB_ID(''' + @DBName + ''')
          AND mid.schema_name IS NOT NULL
          AND mid.user_seeks > 100
        ORDER BY mig.avg_total_user_cost * mig.avg_user_impact DESC;';
        
        BEGIN TRY
            EXEC sp_executesql @SQL;
        END TRY
        BEGIN CATCH
            PRINT 'Error processing ' + @DBName + ': ' + ERROR_MESSAGE();
        END CATCH
        
        FETCH NEXT FROM db_cursor INTO @DBName;
    END
    
    CLOSE db_cursor;
    DEALLOCATE db_cursor;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

CREATE OR ALTER PROCEDURE dba.MarkIndexImplemented
    @RecID BIGINT,
    @Notes NVARCHAR(MAX) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE dba.IndexRecommendations
    SET IsImplemented = 1,
        ImplementedDate = GETDATE(),
        Notes = @Notes
    WHERE RecID = @RecID;
    
    -- Return the CREATE statement
    SELECT CreateStatement
    FROM dba.IndexRecommendations
    WHERE RecID = @RecID;
END
GO

CREATE OR ALTER VIEW dba.vIndexRecommendations
AS
SELECT TOP 100
    RecID,
    ServerName,
    CaptureTime,
    DatabaseName,
    SchemaName,
    TableName,
    IndexColumns,
    IncludedColumns,
    EstimatedImpact,
    AvgUserSeekSeconds,
    UserSeeks,
    LEFT(Statement, 100) AS QuerySnippet,
    CreateStatement,
    CASE
        WHEN EstimatedImpact >= 50 THEN 'HIGH'
        WHEN EstimatedImpact >= 25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Priority
FROM dba.IndexRecommendations
WHERE IsImplemented = 0
  AND CaptureTime >= DATEADD(DAY, -7, GETDATE())
ORDER BY EstimatedImpact DESC, UserSeeks DESC;
GO

CREATE OR ALTER VIEW dba.vUnusedIndexes
AS
SELECT 
    OBJECT_NAME(s.object_id) AS TableName,
    i.name AS IndexName,
    i.type_desc AS IndexType,
    s.user_seeks,
    s.user_scans,
    s.user_lookups,
    s.user_updates,
    i.is_primary_key,
    i.is_unique,
    pg.index_columns AS IndexedColumns,
    CASE
        WHEN s.user_seeks = 0 AND s.user_scans = 0 AND s.user_lookups = 0 THEN 'UNUSED - DROP CANDIDATE'
        WHEN s.user_seeks = 0 AND s.user_scans < 10 THEN 'RARELY USED'
        ELSE 'IN USE'
    END AS Recommendation
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
CROSS APPLY (
    SELECT STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal)
    FROM sys.index_columns ic
    JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
    WHERE ic.object_id = i.object_id AND ic.index_id = i.index_id AND ic.key_ordinal > 0
) pg(index_columns)
WHERE OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
  AND s.database_id = DB_ID()
ORDER BY s.user_seeks + s.user_scans ASC;
GO

CREATE OR ALTER PROCEDURE dba.GenerateDropIndexScript
    @MinDaysUnused INT = 30,
    @MinSizeKB INT = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    PRINT '-- Unused Indexes - Review before dropping';
    PRINT '-- Generated: ' + CAST(GETDATE() AS VARCHAR);
    PRINT '-- Criteria: Not used in ' + CAST(@MinDaysUnused AS VARCHAR) + '+ days and size >= ' + CAST(@MinSizeKB AS VARCHAR) + 'KB';
    PRINT '';
    
    SELECT 
        'USE [' + DB_NAME() + '];' + CHAR(13) + CHAR(10) +
        'DROP INDEX [' + i.name + '] ON [' + SCHEMA_NAME(o.schema_id) + '].[' + o.name + '];' AS DropScript,
        DB_NAME() AS DatabaseName,
        SCHEMA_NAME(o.schema_id) + '.' + o.name AS TableName,
        i.name AS IndexName,
        ps.used_page_count * 8 AS SizeKB,
        s.user_seeks + s.user_scans AS TotalReads
    FROM sys.dm_db_index_usage_stats s
    JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
    JOIN sys.objects o ON s.object_id = o.object_id
    JOIN sys.dm_db_partition_stats ps ON i.object_id = ps.object_id AND i.index_id = ps.index_id
    WHERE s.database_id = DB_ID()
      AND OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
      AND i.is_primary_key = 0
      AND i.is_unique = 0
      AND i.name IS NOT NULL
      AND (s.user_seeks = 0 AND s.user_scans = 0)
      AND s.last_user_seek < DATEADD(DAY, -@MinDaysUnused, GETDATE())
      AND s.last_user_scan < DATEADD(DAY, -@MinDaysUnused, GETDATE())
      AND ps.used_page_count * 8 >= @MinSizeKB
    ORDER BY ps.used_page_count DESC;
END
GO

PRINT 'Index recommendations and unused index analysis created.';
PRINT 'Run CaptureIndexRecommendations weekly to gather data.';
PRINT 'Review vIndexRecommendations before creating indexes.';
PRINT 'Review vUnusedIndexes for potential drops.';
