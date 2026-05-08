-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

-- Capture wait statistics
CREATE OR ALTER PROCEDURE dba.CaptureWaitStats
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @ClearWaitStats BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.WaitStatsHistory (ServerName, WaitType, WaitTimeMs, SignalWaitTimeMs, WaitingTasks)
    SELECT 
        @ServerName,
        wait_type,
        wait_time_ms,
        signal_wait_time_ms,
        waiting_tasks_count
    FROM sys.dm_os_wait_stats
    WHERE wait_time_ms > 0
      AND waiting_tasks_count > 0;
    
    IF @ClearWaitStats = 1
    BEGIN
        DBCC SQLPERF ('sys.dm_os_wait_stats', CLEAR);
    END
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

-- Capture performance counters
CREATE OR ALTER PROCEDURE dba.CapturePerfCounters
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.PerfCounters (ServerName, ObjectName, CounterName, InstanceName, CNTR_VALUE, CNTR_TYPE)
    SELECT 
        @ServerName,
        object_name,
        counter_name,
        instance_name,
        cntr_value,
        cntr_type
    FROM sys.dm_os_performance_counters
    WHERE cntr_value > 0;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

-- Capture database sizes
CREATE OR ALTER PROCEDURE dba.CaptureDatabaseSizes
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
      AND d.is_read_only = 0
    GROUP BY d.name;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

-- Log failed login attempts
CREATE OR ALTER PROCEDURE dba.LogFailedLogin
    @LoginName NVARCHAR(128),
    @ErrorNumber INT,
    @ErrorMessage NVARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.LoginAudit (LoginName, EventType, ErrorNumber, ErrorMessage, IsSuccessful)
    VALUES (@LoginName, 'FAILED_LOGIN', @ErrorNumber, @ErrorMessage, 0);
END
GO

-- Capture login events (call from server trigger)
CREATE OR ALTER PROCEDURE dba.LogLoginEvent
    @LoginName NVARCHAR(128),
    @SessionID INT,
    @HostName NVARCHAR(128),
    @ProgramName NVARCHAR(256),
    @IPAddress NVARCHAR(50),
    @EventType NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.LoginAudit (LoginName, SessionID, HostName, ProgramName, IPAddress, EventType)
    VALUES (@LoginName, @SessionID, @HostName, @ProgramName, @IPAddress, @EventType);
END
GO

-- Log backup operations
CREATE OR ALTER PROCEDURE dba.LogBackup
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DatabaseName NVARCHAR(128),
    @BackupType CHAR(1),
    @BackupStart DATETIME,
    @BackupFinish DATETIME,
    @BackupSizeMB BIGINT,
    @BackupLocation NVARCHAR(500),
    @UserName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.BackupHistory (
        ServerName, DatabaseName, BackupType, BackupStart, BackupFinish,
        BackupSizeMB, BackupLocation, UserName
    )
    VALUES (
        @ServerName, @DatabaseName, @BackupType, @BackupStart, @BackupFinish,
        @BackupSizeMB, @BackupLocation, @UserName
    );
END
GO

-- Index maintenance
CREATE OR ALTER PROCEDURE dba.IndexMaintenance
    @DatabaseName NVARCHAR(128) = NULL,
    @MinFragPercent INT = 5,
    @MaxFragPercent INT = 100,
    @RebuildThreshold INT = 30,
    @MinPageCount INT = 1000,
    @LogOnly BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @TableName NVARCHAR(256);
    DECLARE @IndexName NVARCHAR(256);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE @Frag DECIMAL(5,2);
    DECLARE @Pages BIGINT;
    DECLARE @ObjectID INT;
    DECLARE @DBID INT;
    
    SET @DBID = DB_ID(@DatabaseName);
    
    DECLARE @FragCursor CURSOR;
    
    SET @FragCursor = CURSOR FOR
    SELECT 
        ips.object_id,
        OBJECT_SCHEMA_NAME(ips.object_id, @DBID) AS SchemaName,
        OBJECT_NAME(ips.object_id, @DBID) AS TableName,
        i.name AS IndexName,
        ips.avg_fragmentation_in_percent,
        ips.page_count
    FROM sys.dm_db_index_physical_stats(@DBID, NULL, NULL, NULL, 'LIMITED') ips
    JOIN sys.indexes i ON ips.object_id = i.object_id AND ips.index_id = i.index_id
    WHERE ips.object_id > 100
      AND OBJECTPROPERTY(ips.object_id, 'IsUserTable') = 1
      AND ips.page_count > @MinPageCount
      AND ips.avg_fragmentation_in_percent BETWEEN @MinFragPercent AND @MaxFragPercent
    ORDER BY ips.avg_fragmentation_in_percent DESC;
    
    OPEN @FragCursor;
    FETCH NEXT FROM @FragCursor INTO @ObjectID, @SchemaName, @TableName, @IndexName, @Frag, @Pages;
    
    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @Frag >= @RebuildThreshold
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @DatabaseName + '].[' + @SchemaName + '].[' + @TableName + '] REBUILD;';
        END
        ELSE
        BEGIN
            SET @SQL = 'ALTER INDEX [' + @IndexName + '] ON [' + @DatabaseName + '].[' + @SchemaName + '].[' + @TableName + '] REORGANIZE;';
        END
        
        INSERT INTO dba.IndexMaintenanceLog (ServerName, DatabaseName, TableName, IndexName, OperationType, FragBefore, PagesBefore)
        VALUES (@@SERVERNAME, @DatabaseName, @TableName, @IndexName, 
                CASE WHEN @Frag >= @RebuildThreshold THEN 'REBUILD' ELSE 'REORGANIZE' END,
                @Frag, @Pages);
        
        IF @LogOnly = 0
        BEGIN
            BEGIN TRY
                EXEC sp_executesql @SQL;
                
                UPDATE dba.IndexMaintenanceLog 
                SET OperationFinish = GETDATE(),
                    DurationSeconds = DATEDIFF(SECOND, OperationStart, GETDATE()),
                    Status = 'Success'
                WHERE MaintenanceID = SCOPE_IDENTITY();
            END TRY
            BEGIN CATCH
                UPDATE dba.IndexMaintenanceLog 
                SET OperationFinish = GETDATE(),
                    ErrorMessage = ERROR_MESSAGE(),
                    Status = 'Failed'
                WHERE MaintenanceID = SCOPE_IDENTITY();
            END CATCH
        END
        
        FETCH NEXT FROM @FragCursor INTO @ObjectID, @SchemaName, @TableName, @IndexName, @Frag, @Pages;
    END
    
    CLOSE @FragCursor;
    DEALLOCATE @FragCursor;
END
GO

-- Capture query stats
CREATE OR ALTER PROCEDURE dba.CaptureQueryStats
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @Top INT = 100,
    @MinElapsedMS INT = 1000
AS
BEGIN
    SET NOCOUNT ON;
    
    INSERT INTO dba.QueryStatsSnapshot (
        ServerName, DatabaseName, QueryHash, QueryText,
        ExecutionCount, TotalElapsedMS, TotalLogicalReads, TotalPhysicalReads,
        TotalWorkerTimeMS, AvgElapsedMS, AvgLogicalReads, LastExecutionTime
    )
    SELECT TOP (@Top)
        @ServerName,
        DB_NAME(DB_ID()),
        qs.query_hash,
        SUBSTRING(qt.text, 1, 1000),
        qs.execution_count,
        qs.total_elapsed_time,
        qs.total_logical_reads,
        qs.total_physical_reads,
        qs.total_worker_time,
        qs.total_elapsed_time / NULLIF(qs.execution_count, 0),
        qs.total_logical_reads / NULLIF(qs.execution_count, 0),
        qs.last_execution_time
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
    WHERE qs.total_elapsed_time >= @MinElapsedMS
    ORDER BY qs.total_elapsed_time DESC;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

-- Purge old data
CREATE OR ALTER PROCEDURE dba.PurgeOldData
    @RetentionDays INT = 30,
    @TablesToPurge NVARCHAR(MAX) = 'WaitStatsHistory,PerfCounters,DatabaseSizeHistory,QueryStatsSnapshot'
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE());
    
    -- WaitStatsHistory
    IF CHARINDEX('WaitStatsHistory', @TablesToPurge) > 0
    BEGIN
        DELETE FROM dba.WaitStatsHistory WHERE CaptureTime < @CutoffDate;
        PRINT 'Purged WaitStatsHistory: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
    END
    
    -- PerfCounters
    IF CHARINDEX('PerfCounters', @TablesToPurge) > 0
    BEGIN
        DELETE FROM dba.PerfCounters WHERE CaptureTime < @CutoffDate;
        PRINT 'Purged PerfCounters: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
    END
    
    -- DatabaseSizeHistory
    IF CHARINDEX('DatabaseSizeHistory', @TablesToPurge) > 0
    BEGIN
        DELETE FROM dba.DatabaseSizeHistory WHERE CaptureTime < @CutoffDate;
        PRINT 'Purged DatabaseSizeHistory: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
    END
    
    -- QueryStatsSnapshot
    IF CHARINDEX('QueryStatsSnapshot', @TablesToPurge) > 0
    BEGIN
        DELETE FROM dba.QueryStatsSnapshot WHERE CaptureTime < @CutoffDate;
        PRINT 'Purged QueryStatsSnapshot: ' + CAST(@@ROWCOUNT AS VARCHAR) + ' rows';
    END
END
GO

PRINT 'Core procedures created successfully.';
