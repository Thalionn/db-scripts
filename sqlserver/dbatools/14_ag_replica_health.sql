-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

-- Drop tables if they exist to allow re-running the script
IF OBJECT_ID('dba.AGReplicaHealth', 'U') IS NOT NULL
    DROP TABLE dba.AGReplicaHealth;
IF OBJECT_ID('dba.AGDatabaseSync', 'U') IS NOT NULL
    DROP TABLE dba.AGDatabaseSync;
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
    IsHealthy AS CASE
        WHEN OperationalState = 'ONLINE'
         AND SynchronizationHealth = 'HEALTHY'
         AND RecoveryHealth = 'ONLINE' THEN 1
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
    LastCommitLSN NVARCHAR(50),
    LastCommitTime DATETIME,
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

    -- Capture replica health from sys.availability_groups, sys.availability_replicas, and sys.dm_hadr_availability_replica_states
    INSERT INTO dba.AGReplicaHealth (
        ServerName, AGName, ReplicaName, ReplicaRole, AvailabilityMode,
        FailoverMode, ConnectionState, OperationalState, RecoveryHealth,
        SynchronizationHealth
    )
    SELECT
        @ServerName,
        ag.name AS AGName,
        ar.replica_server_name AS ReplicaName,
        rs.role_desc AS ReplicaRole,
        ar.availability_mode_desc AS AvailabilityMode,
        ar.failover_mode_desc AS FailoverMode,
        rs.connected_state_desc AS ConnectionState,
        rs.operational_state_desc AS OperationalState,
        rs.recovery_health_desc AS RecoveryHealth,
        rs.synchronization_health_desc AS SynchronizationHealth
    FROM sys.availability_groups ag
    JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
    JOIN sys.dm_hadr_availability_replica_states rs ON ar.replica_id = rs.replica_id;

    -- Capture database sync state from sys.availability_databases_cluster, sys.availability_groups,
    -- sys.availability_replicas, and sys.dm_hadr_database_replica_states
    INSERT INTO dba.AGDatabaseSync (
        ServerName, AGName, DatabaseName, ReplicaName, IsLocal,
        SynchronizationState, SynchronizationHealth, LastCommitLSN, LastCommitTime
    )
    SELECT
        @ServerName,
        ag.name AS AGName,
        adc.database_name AS DatabaseName,
        ar.replica_server_name AS ReplicaName,
        dbrs.is_local,
        dbrs.synchronization_state_desc AS SynchronizationState,
        dbrs.synchronization_health_desc AS SynchronizationHealth,
        CONVERT(NVARCHAR(50), dbrs.last_commit_lsn, 1) AS LastCommitLSN,
        dbrs.last_commit_time AS LastCommitTime
    FROM sys.availability_databases_cluster adc
    JOIN sys.availability_groups ag ON adc.group_id = ag.group_id
    JOIN sys.availability_replicas ar ON adc.group_id = ar.group_id
    JOIN sys.dm_hadr_database_replica_states dbrs ON adc.group_database_id = dbrs.group_database_id
        AND ar.replica_id = dbrs.replica_id;

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
        WHEN SynchronizationHealth = 'HEALTHY' THEN 'OK'
        ELSE 'CHECK'
    END AS HealthStatus
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
    ar.replica_server_name AS ReplicaName,
    rs.role_desc AS CurrentRole,
    rs.is_local AS IsLocal,
    rs.operational_state_desc AS OperationalState,
    rs.synchronization_health_desc AS SynchronizationHealth
FROM sys.availability_groups ag
JOIN sys.availability_replicas ar ON ag.group_id = ar.group_id
JOIN sys.dm_hadr_availability_replica_states rs ON ar.replica_id = rs.replica_id;
GO

PRINT 'Availability Group monitoring created.';
PRINT 'Run CaptureAGHealth every 5 minutes for history tracking.';
PRINT 'Note: Returns message if no AGs exist on instance.';
GO
