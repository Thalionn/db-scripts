-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Script: 01_tables.sql
-- Purpose: Create core DBATools tables
-- Usage:   Run after 00_create_database.sql
-- Notes:   All tables use dba schema
-- ============================================================================

USE DBATools;
GO

-- Server inventory
CREATE TABLE dba.ServerInventory (
    ServerID INT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128) NOT NULL,
    InstanceName NVARCHAR(128) DEFAULT 'DEFAULT',
    Environment NVARCHAR(50), -- PROD, UAT, DEV, etc.
    IsActive BIT DEFAULT 1,
    DateAdded DATETIME DEFAULT GETDATE(),
    Notes NVARCHAR(MAX),
    CONSTRAINT UQ_ServerInstance UNIQUE (ServerName, InstanceName)
);
GO

-- Login audit trail
CREATE TABLE dba.LoginAudit (
    AuditID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    LoginName NVARCHAR(128) NOT NULL,
    LoginType NVARCHAR(50),
    SessionID INT,
    HostName NVARCHAR(128),
    ProgramName NVARCHAR(256),
    IPAddress NVARCHAR(50),
    LoginTime DATETIME DEFAULT GETDATE(),
    EventType NVARCHAR(50), -- LOGIN, LOGOUT, FAILED_LOGIN
    ErrorNumber INT,
    ErrorMessage NVARCHAR(MAX),
    IsSuccessful BIT DEFAULT 1,
    INDEX IX_LoginAudit_Times NONCLUSTERED (LoginTime),
    INDEX IX_LoginAudit_LoginName NONCLUSTERED (LoginName)
);
GO

-- Wait statistics snapshot
CREATE TABLE dba.WaitStatsHistory (
    SnapshotID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    WaitType NVARCHAR(128) NOT NULL,
    WaitTimeMs BIGINT,
    SignalWaitTimeMs INT,
    WaitingTasks INT,
    INDEX IX_WaitStats_Capture NONCLUSTERED (CaptureTime),
    INDEX IX_WaitStats_Type NONCLUSTERED (WaitType)
);
GO

-- Performance counters
CREATE TABLE dba.PerfCounters (
    CounterID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    ObjectName NVARCHAR(128),
    CounterName NVARCHAR(128),
    InstanceName NVARCHAR(128),
    CNTR_VALUE BIGINT,
    CNTR_TYPE INT,
    INDEX IX_PerfCounters_Capture NONCLUSTERED (CaptureTime, ObjectName)
);
GO

-- Database size history
CREATE TABLE dba.DatabaseSizeHistory (
    SizeID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128) NOT NULL,
    CaptureTime DATETIME DEFAULT GETDATE(),
    DataFileSizeMB BIGINT,
    LogFileSizeMB BIGINT,
    TotalSizeMB AS DataFileSizeMB + LogFileSizeMB,
    SpaceUsedMB BIGINT,
    SpaceAvailableMB BIGINT,
    INDEX IX_DBSize_Capture NONCLUSTERED (CaptureTime),
    INDEX IX_DBSize_Database NONCLUSTERED (DatabaseName, CaptureTime)
);
GO

-- Backup history
CREATE TABLE dba.BackupHistory (
    BackupID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128) NOT NULL,
    BackupType CHAR(1), -- D=Full, I=Differential, L=Log
    BackupStart DATETIME,
    BackupFinish DATETIME,
    DurationSeconds AS DATEDIFF(SECOND, BackupStart, BackupFinish),
    BackupSizeMB BIGINT,
    BackupLocation NVARCHAR(500),
    DeviceType CHAR(1),
    IsCompressed BIT,
    IsEncrypted BIT,
    BackupSetName NVARCHAR(128),
    Description NVARCHAR(MAX),
    UserName NVARCHAR(128),
    RecoveryModel NVARCHAR(20),
    INDEX IX_Backup_Database NONCLUSTERED (DatabaseName, BackupStart DESC),
    INDEX IX_Backup_TypeTime NONCLUSTERED (BackupType, BackupStart)
);
GO

-- Index maintenance log
CREATE TABLE dba.IndexMaintenanceLog (
    MaintenanceID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    TableName NVARCHAR(256),
    IndexName NVARCHAR(256),
    OperationType NVARCHAR(50), -- REBUILD, REORGANIZE, CREATE, DROP
    OperationStart DATETIME DEFAULT GETDATE(),
    OperationFinish DATETIME,
    DurationSeconds INT,
    FragBefore DECIMAL(5,2),
    FragAfter DECIMAL(5,2),
    PagesBefore BIGINT,
    PagesAfter BIGINT,
    ErrorMessage NVARCHAR(MAX),
    Status NVARCHAR(20) DEFAULT 'Success' -- Success, Failed, Skipped
);
GO

-- Job history summary
CREATE TABLE dba.JobHistorySummary (
    SummaryID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    JobName NVARCHAR(256),
    RunDate DATE,
    TotalRuns INT,
    SucceededRuns INT,
    FailedRuns INT,
    CanceledRuns INT,
    AvgDurationSeconds INT,
    LastRunStatus NVARCHAR(50),
    LastRunTime DATETIME,
    INDEX IX_JobHistory_JobDate NONCLUSTERED (JobName, RunDate DESC)
);
GO

-- Query performance snapshots
CREATE TABLE dba.QueryStatsSnapshot (
    StatsID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    DatabaseName NVARCHAR(128),
    QueryHash BINARY(8),
    QueryText NVARCHAR(MAX),
    ExecutionCount BIGINT,
    TotalElapsedMS BIGINT,
    TotalLogicalReads BIGINT,
    TotalPhysicalReads BIGINT,
    TotalWorkerTimeMS BIGINT,
    AvgElapsedMS BIGINT,
    AvgLogicalReads BIGINT,
    LastExecutionTime DATETIME,
    PlanHandle VARBINARY(64),
    QueryPlan XML,
    INDEX IX_QueryStats_Capture NONCLUSTERED (CaptureTime),
    INDEX IX_QueryStats_Hash NONCLUSTERED (QueryHash)
);
GO

PRINT 'Core tables created successfully.';
