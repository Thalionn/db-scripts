-- ============================================================================
-- Script: 14_ag_replica_health.sql
-- Purpose: Availability Group health monitoring
-- Usage:   Run on primary replica; schedule for regular health checks
-- Notes:   Requires VIEW ANY DEFINITION permission or sysadmin
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.AGReplicaHealth (
    HealthID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    AGName NVARCHAR(256),
    ReplicaName NVARCHAR(256),
    ReplicaRole NVARCHAR(50),
    AvailabilityMode NVARCHAR(50),
    FailoverMode NVARCHAR(50),
    ConnectionState NVARCHAR(50),
    OperationalState NVARCHAR(50),
    RecoveryHealth NVARCHAR(50),
    SynchronizationHealth NVARCHAR(50),
    LastSyncedTime DATETIME,
    LastRedoTime DATETIME,
    RedoQueueSizeMB BIGINT,
    LogSendQueueSizeMB BIGINT,
    EstimatedRecoveryTime INT,
    IsHealthy AS CASE 
        WHEN OperationalState = 'Online' 
         AND SynchronizationHealth = 'Healthy' 
         AND RecoveryHealth = 'Online' THEN 1 
        ELSE 0 
    END,
    INDEX IX_AGHealth_Capture NONCLUSTERED (CaptureTime, AGName),
    INDEX IX_AGHealth_Replica NONCLUSTERED (ReplicaName, CaptureTime)
);
GO

CREATE TABLE dba.AGDatabaseSync (
    SyncID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    AGName NVARCHAR(256),
    DatabaseName NVARCHAR(256),
    ReplicaName NVARCHAR(256),
    IsLocal BIT,
    SynchronizationState NVARCHAR(50),
    SynchronizationHealth NVARCHAR(50),
    LastLSN INT,
    LastCommitLSN BIGINT,
    LastCommitTime DATETIME,
    LogStreamSizeMB BIGINT,
    INDEX IX_AGDB_Capture NONCLUSTERED (CaptureTime, AGName)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureAGHealth
    @ServerName NVARCHAR(128) = @@SERVERNAME
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Check if AGs exist
    IF NOT EXISTS (SELECT 1 FROM sys.availability_groups)
    BEGIN
        PRINT 'No Availability Groups found on this instance.';
        RETURN;
    END
    
    -- Capture replica health
    INSERT INTO dba.AGReplicaHealth (
        ServerName, AGName, ReplicaName, ReplicaRole, AvailabilityMode,
        FailoverMode, ConnectionState, OperationalState, RecoveryHealth,
        SynchronizationHealth, LastSyncedTime, LastRedoTime, RedoQueueSizeMB,
        LogSendQueueSizeMB, EstimatedRecoveryTime
    )
    SELECT 
        @ServerName,
        ag.name AS AGName,
        ar.replica_server_name AS ReplicaName,
        ar.role_desc AS ReplicaRole,
        ar.availability_mode_desc AS AvailabilityMode,
        ar.failover_mode_desc AS FailoverMode,
        rs.connected_state_desc AS ConnectionState,
        rs.operational_state_desc AS OperationalState,
        rs.recovery_health_desc AS RecoveryHealth,
        rs.synchronization_health_desc AS SynchronizationHealth,
        rs.last_sent_time,
        rs.last_received_time,
        rs.last_redone_time,
        CAST(rs.redo_rate / 1024.0 AS BIGINT) AS RedoQueueSizeMB,
        CAST(rs.log_send_rate / 1024.0 AS BIGINT) AS LogSendQueueSizeMB,
        rs.estimated_recovery_time,
        CASE WHEN rs.role_desc = 'PRIMARY' THEN 1 ELSE 0 END AS IsPrimary
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states rs ON ar.replica_id = rs.replica_id;
    
    -- Capture database sync state
    INSERT INTO dba.AGDatabaseSync (
        ServerName, AGName, DatabaseName, ReplicaName, IsLocal,
        SynchronizationState, SynchronizationHealth, LastCommitLSN, LastCommitTime
    )
    SELECT 
        @ServerName,
        ag.name AS AGName,
        d.database_name AS DatabaseName,
        ar.replica_server_name AS ReplicaName,
        d.is_local,
        d.synchronization_state_desc AS SynchronizationState,
        d.synchronization_health_desc AS SynchronizationHealth,
        d.last_sent_lsn,
        d.last_commit_lsn,
        d.last_commit_time
    FROM sys.availability_databases_cluster adc
    JOIN sys.availability_groups ag ON adc.group_id = ag.group_id
    JOIN sys.availability_replicas ar ON adc.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_database_states d ON adc.group_database_id = d.group_database_id;
    
    SELECT @@SERVERNAME AS ServerName, GETDATE() AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

CREATE OR ALTER VIEW dba.vAGReplicaHealth
AS
SELECT 
    ServerName,
    CaptureTime,
    AGName,
    ReplicaName,
    ReplicaRole,
    ConnectionState,
    OperationalState,
    SynchronizationHealth,
    CASE 
        WHEN RedoQueueSizeMB > 100 THEN 'HIGH LAG'
        WHEN LogSendQueueSizeMB > 50 THEN 'SEND LAG'
        ELSE 'OK'
    END AS LagStatus,
    LastSyncedTime,
    CASE 
        WHEN IsHealthy = 1 THEN 'HEALTHY'
        ELSE 'UNHEALTHY'
    END AS HealthStatus,
    CASE
        WHEN ReplicaRole = 'PRIMARY' AND IsHealthy = 0 THEN 'ACTION REQUIRED'
        ELSE ''
    END AS ActionRequired
FROM dba.AGReplicaHealth
WHERE CaptureTime >= DATEADD(HOUR, -24, GETDATE());
GO

CREATE OR ALTER VIEW dba.vAGDatabaseSync
AS
SELECT 
    ServerName,
    CaptureTime,
    AGName,
    DatabaseName,
    ReplicaName,
    IsLocal,
    SynchronizationState,
    SynchronizationHealth,
    LastCommitTime,
    DATEDIFF(MINUTE, LastCommitTime, GETDATE()) AS SyncLagMinutes
FROM dba.AGDatabaseSync
WHERE CaptureTime >= DATEADD(HOUR, -24, GETDATE());
GO

CREATE OR ALTER VIEW dba.vAGFailoverHistory
AS
SELECT 
    ag.name AS AGName,
    aro.primary_replica AS OldPrimary,
    ar.primary_replica AS NewPrimary,
    ars.role_desc AS CurrentRole,
    ars.is_local
FROM sys.availability_groups ag
CROSS APPLY (
    SELECT TOP 1 replica_server_name AS primary_replica
    FROM sys.availability_replicas
    WHERE group_id = ag.group_id AND role_desc = 'PRIMARY'
) ar
CROSS APPLY (
    SELECT TOP 1 replica_server_name AS primary_replica
    FROM sys.availability_replicas
    WHERE group_id = ag.group_id AND role_desc = 'SECONDARY'
) aro
JOIN sys.dm_hadr_availability_replica_states ars ON ar.replica_id = ars.replica_id;
GO

PRINT 'Availability Group monitoring created.';
PRINT 'Run CaptureAGHealth every 5 minutes for history tracking.';
PRINT 'Note: Returns message if no AGs exist on instance.';
