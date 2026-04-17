-- =============================================
-- SQL Server Practice Environment Setup Script
-- Creates simulated users, apps, and scheduled jobs for practice
-- Uses AdventureWorks database as the foundation
-- =============================================

USE master;
GO

-- Enable advanced options if needed
IF NOT EXISTS (SELECT * FROM sys.configurations WHERE name = 'show advanced options' AND value_in_use = 1)
BEGIN
    EXEC sp_configure 'show advanced options', 1;
    RECONFIGURE;
END
GO

USE AdventureWorks2019; -- Or your installed version
GO

-- =============================================
-- SECTION 1: Create Simulated User Roles
-- =============================================

PRINT 'Creating simulated user roles...';

-- 1. Sales Representative (SalesApp)
CREATE USER [SalesApp] FOR LOGIN [SalesAppLogin];
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Sales TO [SalesApp];
GRANT EXECUTE ON OBJECT::Sales.SalesOrderHeader TO [SalesApp];
GO

-- 2. Warehouse Manager (WarehouseApp)
CREATE USER [WarehouseApp] FOR LOGIN [WarehouseAppLogin];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Production TO [WarehouseApp];
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Person TO [WarehouseApp];
GO

-- 3. Inventory Analyst (AnalyticsApp)
CREATE USER [AnalyticsApp] FOR LOGIN [AnalyticsAppLogin];
GRANT SELECT ON SCHEMA::Sales;
GRANT SELECT ON SCHEMA::Production;
GRANT SELECT ON SCHEMA::Person;
GRANT SELECT ON SCHEMA::Purchasing;
GO

-- 4. HR Specialist (HRApp)
CREATE USER [HRApp] FOR LOGIN [HRAppLogin];
GRANT SELECT, INSERT, UPDATE ON SCHEMA::HumanResources TO [HRApp];
GRANT SELECT ON SCHEMA::Person;
GO

-- 5. Customer Service Rep (CSApp)
CREATE USER [CSApp] FOR LOGIN [CSAppLogin];
GRANT SELECT ON SCHEMA::Sales;
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Person;
GRANT EXECUTE ON OBJECT::Sales.SalesOrderHeader TO [CSApp];
GO

-- 6. Executive Dashboard (ExecutiveApp)
CREATE USER [ExecutiveApp] FOR LOGIN [ExecutiveAppLogin];
GRANT SELECT ON SCHEMA::Sales;
GRANT SELECT ON SCHEMA::Production;
GRANT SELECT ON SCHEMA::Person;
GRANT SELECT ON SCHEMA::Purchasing;
GRANT EXECUTE ON ALL TABLES IN Sales TO [ExecutiveApp];
GO

-- =============================================
-- SECTION 2: Create Simulated Application Jobs
-- =============================================

PRINT 'Creating application simulation jobs...';

-- Job ID 1: Daily Sales Report Generation (SalesApp)
DECLARE @salesReportJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'SalesApp_Daily_Report',
    @enabled = 1,
    @description = N'Generates daily sales summary for Sales representative view',
    @job_id = @salesReportJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'SalesApp_Daily_Report',
    @step_name = N'Generate Sales Summary',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;
DECLARE @reportDate DATE = CONVERT(DATE, GETDATE());

-- Create daily sales summary table
IF OBJECT_ID('SalesApp_Daily_SalesSummary') IS NOT NULL
    DROP TABLE SalesApp_Daily_SalesSummary;

CREATE TABLE SalesApp_Daily_SalesSummary (
    ReportDate DATE PRIMARY KEY,
    TotalSales DECIMAL(18,2),
    OrderCount INT,
    UniqueCustomers INT,
    TopProduct NVARCHAR(50)
);

INSERT INTO SalesApp_Daily_SalesSummary (ReportDate, TotalSales, OrderCount, UniqueCustomers, TopProduct)
SELECT 
    CONVERT(DATE, GETDATE()) AS ReportDate,
    SUM(TotalDue) AS TotalSales,
    COUNT(*) AS OrderCount,
    COUNT(DISTINCT SalesOrderNumber) AS UniqueCustomers,
    TOP 1 ProductName FROM (
        SELECT p.Name AS ProductName, SUM(so.TotalDue) as Amount
        FROM Sales.SalesOrderDetail sod
        JOIN Production.Product p ON sod.ProductID = p.ProductID
        GROUP BY p.Name
    ) ranked
    ORDER BY Amount DESC LIMIT 1;

SELECT * FROM SalesApp_Daily_SalesSummary WHERE ReportDate = @reportDate;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'SalesApp_Daily_Report',
    @server_name = N'(local)';

-- Schedule: Daily at 9 AM
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @active_start_time = 540; -- 9:00 AM (HHMM)

-- Job ID 2: Inventory Reorder Alert (WarehouseApp)
DECLARE @inventoryJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'WarehouseApp_Inventory_Alert',
    @enabled = 1,
    @description = N'Monitors inventory levels and alerts on low stock items',
    @job_id = @inventoryJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'WarehouseApp_Inventory_Alert',
    @step_name = N'Check Inventory Levels',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create inventory alert table
IF OBJECT_ID('WarehouseApp_LowStockAlert') IS NOT NULL
    DROP TABLE WarehouseApp_LowStockAlert;

CREATE TABLE WarehouseApp_LowStockAlert (
    AlertID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(50),
    CurrentStock INT,
    ReorderPoint INT,
    ShortageAmount INT,
    LastChecked DATETIME DEFAULT GETDATE()
);

INSERT INTO WarehouseApp_LowStockAlert (ProductName, CurrentStock, ReorderPoint, ShortageAmount)
SELECT 
    p.Name AS ProductName,
    inv.Quantity AS CurrentStock,
    CASE WHEN inv.ReorderLevel IS NOT NULL THEN inv.ReorderLevel ELSE 10 END AS ReorderPoint,
    CASE WHEN inv.Quantity < COALESCE(inv.ReorderLevel, 10) 
         THEN 0 - (inv.Quantity - COALESCE(inv.ReorderLevel, 10)) 
         ELSE 0 END AS ShortageAmount
FROM Production.ProductInventory inv
JOIN Production.Product p ON inv.ProductID = p.ProductID
WHERE inv.Quantity < ISNULL(inv.ReorderPoint, 10)
ORDER BY ShortageAmount DESC;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'WarehouseApp_Inventory_Alert',
    @server_name = N'(local)';

-- Schedule: Every 4 hours
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @freq_subday_type = 4, -- Every 4 hours
    @freq_subday_interval = 1;

-- Job ID 3: Customer Order Processing (CSApp)
DECLARE @orderJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'CSApp_Order_Processing',
    @enabled = 1,
    @description = N'Simulates customer order processing and status updates',
    @job_id = @orderJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'CSApp_Order_Processing',
    @step_name = N'Process Pending Orders',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create order processing log
IF OBJECT_ID('CSApp_OrderProcessingLog') IS NOT NULL
    DROP TABLE CSApp_OrderProcessingLog;

CREATE TABLE CSApp_OrderProcessingLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    OrderNumber NVARCHAR(25),
    CustomerName NVARCHAR(100),
    TotalDue DECIMAL(18,2),
    StatusChange NVARCHAR(50),
    ProcessedAt DATETIME DEFAULT GETDATE()
);

-- Simulate processing pending orders (random selection for practice)
DECLARE @orderCount INT = 5; -- Number of orders to process per run
DECLARE @processedOrders TABLE (OrderNumber NVARCHAR(25));

INSERT INTO CSApp_OrderProcessingLog (OrderNumber, CustomerName, TotalDue, StatusChange)
SELECT TOP (@orderCount) 
    so.SalesOrderNumber AS OrderNumber,
    p.FirstName + '' '' + p.LastName AS CustomerName,
    so.TotalDue,
    CASE WHEN so.Status = ''In Process'' THEN ''Completed'' ELSE ''Status Updated'' END AS StatusChange
FROM Sales.SalesOrderHeader so
JOIN Sales.Customer c ON so.CustomerID = c.CustomerID
JOIN Person.Person p ON c.PersonID = p.BusinessEntityID
WHERE so.Status IN (''In Process'', ''Approved'')
ORDER BY so.ModifiedDate DESC;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'CSApp_Order_Processing',
    @server_name = N'(local)';

-- Schedule: Every hour during business hours (9 AM - 6 PM)
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @active_start_time = 540, -- 9:00 AM
    @active_end_time = 1440; -- 6:00 PM

-- Job ID 4: Executive Dashboard Refresh (ExecutiveApp)
DECLARE @execJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'ExecutiveApp_Dashboard_Refresh',
    @enabled = 1,
    @description = N'Refreshes executive dashboard metrics and KPIs',
    @job_id = @execJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'ExecutiveApp_Dashboard_Refresh',
    @step_name = N'Update Executive Metrics',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create executive metrics table
IF OBJECT_ID('ExecutiveApp_Metrics') IS NOT NULL
    DROP TABLE ExecutiveApp_Metrics;

CREATE TABLE ExecutiveApp_Metrics (
    MetricID INT IDENTITY(1,1) PRIMARY KEY,
    MetricName NVARCHAR(50),
    CurrentValue DECIMAL(18,2),
    PreviousValue DECIMAL(18,2),
    ChangePercent DECIMAL(5,2),
    LastUpdated DATETIME DEFAULT GETDATE()
);

-- Insert key metrics
INSERT INTO ExecutiveApp_Metrics (MetricName, CurrentValue, PreviousValue)
SELECT 
    ''TotalRevenue_YTD'' AS MetricName,
    SUM(TotalDue) AS CurrentValue,
    SUM(CASE WHEN SalesOrderDate < DATEADD(MONTH, -1, GETDATE()) THEN TotalDue ELSE 0 END) AS PreviousValue
FROM Sales.SalesOrderHeader
WHERE SalesOrderDate >= DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);

INSERT INTO ExecutiveApp_Metrics (MetricName, CurrentValue, PreviousValue)
SELECT 
    ''ActiveCustomers'' AS MetricName,
    COUNT(DISTINCT CustomerID) AS CurrentValue,
    COUNT(DISTINCT CASE WHEN SalesOrderDate < DATEADD(MONTH, -1, GETDATE()) THEN CustomerID END) AS PreviousValue
FROM Sales.SalesOrderHeader;

INSERT INTO ExecutiveApp_Metrics (MetricName, CurrentValue, PreviousValue)
SELECT 
    ''AvgOrderValue'' AS MetricName,
    AVG(TotalDue) AS CurrentValue,
    AVG(CASE WHEN SalesOrderDate < DATEADD(MONTH, -1, GETDATE()) THEN TotalDue END) AS PreviousValue
FROM Sales.SalesOrderHeader;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'ExecutiveApp_Dashboard_Refresh',
    @server_name = N'(local)';

-- Schedule: Every 6 hours
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @freq_subday_type = 4, -- Every 6 hours
    @freq_subday_interval = 1;

-- Job ID 5: HR Employee Activity Monitor (HRApp)
DECLARE @hrJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'HRApp_Employee_Activity',
    @enabled = 1,
    @description = N'Monitors employee work activity and vacation balances',
    @job_id = @hrJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'HRApp_Employee_Activity',
    @step_name = N'Update Employee Activity',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create employee activity log
IF OBJECT_ID('HRApp_EmployeeActivity') IS NOT NULL
    DROP TABLE HRApp_EmployeeActivity;

CREATE TABLE HRApp_EmployeeActivity (
    ActivityID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeName NVARCHAR(100),
    Department NVARCHAR(50),
    JobTitle NVARCHAR(50),
    VacationHoursRemaining DECIMAL(5,2),
    SickHoursRemaining DECIMAL(5,2),
    LastLogin DATETIME,
    Status NVARCHAR(30)
);

-- Insert current employee status (sample for practice)
INSERT INTO HRApp_EmployeeActivity (EmployeeName, Department, JobTitle, VacationHoursRemaining, SickHoursRemaining, LastLogin, Status)
SELECT 
    p.FirstName + '' '' + p.LastName AS EmployeeName,
    e.Department,
    e.JobTitle,
    CASE WHEN v.VacationHours IS NOT NULL THEN v.VacationHours ELSE 0 END AS VacationHoursRemaining,
    CASE WHEN s.SickLeaveHours IS NOT NULL THEN s.SickLeaveHours ELSE 0 END AS SickHoursRemaining,
    MAX(so.ModifiedDate) AS LastLogin,
    CASE 
        WHEN so.ModifiedDate > DATEADD(HOUR, -24, GETDATE()) THEN ''Active''
        ELSE ''Inactive''
    END AS Status
FROM HumanResources.Employee e
JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
LEFT JOIN HumanResources.EmployeeVacationBalance v ON e.BusinessEntityID = v.BusinessEntityID
LEFT JOIN HumanResources.EmployeeSickLeave s ON e.BusinessEntityID = s.BusinessEntityID
LEFT JOIN Sales.SalesOrderHeader so ON e.BusinessEntityID = so.SalesPersonID
WHERE e.Title NOT IN (''Unemployed'', ''Retired'')
ORDER BY p.LastName;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'HRApp_Employee_Activity',
    @server_name = N'(local)';

-- Schedule: Every 3 hours during business hours
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @active_start_time = 540, -- 9:00 AM
    @active_end_time = 1320; -- 6:00 PM
    @freq_subday_type = 4, -- Every 3 hours
    @freq_subday_interval = 1;

-- =============================================
-- SECTION 3: Create Practice Scenario Jobs
-- =============================================

PRINT 'Creating practice scenario jobs...';

-- Job ID 6: Performance Degradation Simulation (for practice)
DECLARE @perfJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'Practice_Performance_Stress',
    @enabled = 0, -- Disabled by default for safety
    @description = N'Simulates performance stress scenarios for practice (DISABLED)',
    @job_id = @perfJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'Practice_Performance_Stress',
    @step_name = N'Insert Test Data',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- WARNING: Only enable this job for practice purposes!
-- This simulates performance degradation by inserting test data

DECLARE @batchSize INT = 1000; -- Adjust based on your system capacity
DECLARE @totalRows INT = 50000; -- Total rows to insert (adjust as needed)
DECLARE @counter INT = 0;

WHILE @counter < @totalRows
BEGIN
    INSERT INTO Sales.SalesOrderHeader (RevisionNumber, OrderDate, DueDate, Status, OnlineOrderFlag, PurchaseOrderNumber, AccountNumber, CreditCardID, CurrencyRateId, TotalDue, rowguid, ModifiedDate)
    SELECT 
        ABS(CHECKSUM(NEWID())) % 10 + 1 AS RevisionNumber,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 365, ''2024-01-01'') AS OrderDate,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 365 + 30, ''2024-01-01'') AS DueDate,
        ''TS'' AS Status,
        0 AS OnlineOrderFlag,
        ''PO-' + CAST(ABS(CHECKSUM(NEWID())) % 999999 AS VARCHAR) + ''' AS PurchaseOrderNumber,
        ''ACC-' + CAST(ABS(CHECKSUM(NEWID())) % 999999 AS VARCHAR) + ''' AS AccountNumber,
        NULL AS CreditCardID,
        NULL AS CurrencyRateId,
        ABS(CHECKSUM(NEWID())) % 100000.00 AS TotalDue,
        NEWID() AS rowguid,
        GETDATE() AS ModifiedDate;

    SET @counter = @counter + @batchSize;
    
    -- Add small delay to simulate realistic load
    WAITFOR DELAY ''00:00:01'';
END;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'Practice_Performance_Stress',
    @server_name = N'(local)';

-- Job ID 7: Query Pattern Analysis (for practice)
DECLARE @queryJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'Practice_Query_Pattern_Analysis',
    @enabled = 1,
    @description = N'Analyzes query patterns and identifies optimization opportunities',
    @job_id = @queryJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'Practice_Query_Pattern_Analysis',
    @step_name = N'Analyze Query Patterns',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create query pattern analysis table
IF OBJECT_ID('Practice_QueryPatterns') IS NOT NULL
    DROP TABLE Practice_QueryPatterns;

CREATE TABLE Practice_QueryPatterns (
    PatternID INT IDENTITY(1,1) PRIMARY KEY,
    QueryPattern NVARCHAR(MAX),
    ExecutionCount BIGINT,
    TotalElapsedTime MS,
    AvgElapsedTime MS,
    LastExecution DATETIME,
    Recommendation NVARCHAR(200)
);

-- Analyze common query patterns (simplified for practice)
INSERT INTO Practice_QueryPatterns (QueryPattern, ExecutionCount, TotalElapsedTime, AvgElapsedTime, LastExecution, Recommendation)
SELECT 
    CASE 
        WHEN COUNT(*) > 100 THEN ''Frequent Query - Consider indexing''
        ELSE ''Occasional Query''
    END AS Recommendation,
    LEFT(STUFF((
        SELECT ''; '' + SUBSTRING(q.text, (number * 800) + 1, MIN(800, ((END(num) - number * 800 - 1) + 1)))
        FROM sys.dm_exec_query_stats qs
        CROSS JOIN (SELECT TOP (20) ROW_NUMBER() OVER (ORDER BY qs.total_elapsed_time DESC) AS num 
                     FROM sys.dm_exec_query_stats) num
        WHERE qs.query_hash = qs.query_hash
        FOR XML PATH('' '')
    ), 1, 1, '''') AS LEFT(500), -- Truncate for practice
    COUNT(*) OVER () AS ExecutionCount,
    SUM(total_elapsed_time) OVER () AS TotalElapsedTime,
    AVG(total_elapsed_time) OVER () AS AvgElapsedTime,
    MAX(last_execution_time) OVER () AS LastExecution
FROM sys.dm_exec_query_stats qs;

SELECT TOP 10 * FROM Practice_QueryPatterns ORDER BY ExecutionCount DESC;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'Practice_Query_Pattern_Analysis',
    @server_name = N'(local)';

-- Schedule: Daily at midnight
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @active_start_time = 0; -- Midnight (HHMM)

-- =============================================
-- SECTION 4: Create Practice Monitoring Jobs
-- =============================================

PRINT 'Creating practice monitoring jobs...';

-- Job ID 8: Lock Contention Monitor (for practice)
DECLARE @lockJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'Practice_Lock_Monitor',
    @enabled = 1,
    @description = N'Monitors lock contention and blocking for practice',
    @job_id = @lockJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'Practice_Lock_Monitor',
    @step_name = N'Check Locks',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Create lock monitoring table
IF OBJECT_ID('Practice_LockMonitor') IS NOT NULL
    DROP TABLE Practice_LockMonitor;

CREATE TABLE Practice_LockMonitor (
    MonitorID INT IDENTITY(1,1) PRIMARY KEY,
    CheckTime DATETIME DEFAULT GETDATE(),
    TotalLocks INT,
    BlockedSessions INT,
    TopBlockedSession SPID,
    LockDetails NVARCHAR(MAX)
);

INSERT INTO Practice_LockMonitor (TotalLocks, BlockedSessions, TopBlockedSession, LockDetails)
SELECT 
    COUNT(*) AS TotalLocks,
    SUM(CASE WHEN blocking_session_id IS NOT NULL THEN 1 ELSE 0 END) AS BlockedSessions,
    MAX(blocking_session_id) AS TopBlockedSession,
    STUFF((
        SELECT ''; '' + CAST(request_session_id AS VARCHAR) + '' blocked by '' + CAST(blocking_session_id AS VARCHAR) + '' on '' + OBJECT_NAME(resource_associated_entity_id)
        FROM sys.dm_tran_locks l
        CROSS APPLY sys.dm_exec_requests r
        WHERE l.request_session_id = r.session_id
        FOR XML PATH('' '')
    ), 1, 1, '''') AS LockDetails;

SELECT * FROM Practice_LockMonitor ORDER BY CheckTime DESC LIMIT 5;',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'Practice_Lock_Monitor',
    @server_name = N'(local)';

-- Schedule: Every 30 minutes
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @freq_subday_type = 8, -- Every hour
    @freq_subday_interval = 2; -- Every 30 minutes

-- Job ID 9: Index Usage Monitor (for practice)
DECLARE @indexJobId UNIQUEIDENTIFIER;
EXEC msdb.dbo.sp_add_job 
    @job_name = N'Practice_Index_Usage',
    @enabled = 1,
    @description = N'Monitors index usage statistics for practice',
    @job_id = @indexJobId OUTPUT;

EXEC msdb.dbo.sp_add_jobstep 
    @job_name = N'Practice_Index_Usage',
    @step_name = N'Update Index Usage',
    @subsystem = N'TSQL',
    @command = N'USE AdventureWorks2019;

-- Update index usage statistics (if available)
IF EXISTS (SELECT * FROM sys.dm_db_index_usage_stats WHERE object_id IS NOT NULL)
BEGIN
    -- Create index usage summary table
    IF OBJECT_ID('Practice_IndexUsage') IS NOT NULL
        DROP TABLE Practice_IndexUsage;

    CREATE TABLE Practice_IndexUsage (
        IndexID INT IDENTITY(1,1) PRIMARY KEY,
        TableName NVARCHAR(256),
        IndexName NVARCHAR(256),
        UserSeeks BIGINT,
        UserScans BIGINT,
        UserUpdates BIGINT,
        LastUserSeek DATETIME,
        LastUserScan DATETIME,
        LastUserUpdate DATETIME,
        UsageRatio DECIMAL(10,4)
    );

    INSERT INTO Practice_IndexUsage (TableName, IndexName, UserSeeks, UserScans, UserUpdates, 
                                    LastUserSeek, LastUserScan, LastUserUpdate, UsageRatio)
    SELECT 
        OBJECT_NAME(s.object_id) AS TableName,
        i.name AS IndexName,
        s.user_seeks,
        s.user_scans,
        s.user_updates,
        MAX(DATEADD(MINUTE, -s.last_user_seek, GETDATE())) AS LastUserSeek,
        MAX(DATEADD(MINUTE, -s.last_user_scan, GETDATE())) AS LastUserScan,
        MAX(DATEADD(MINUTE, -s.last_user_update, GETDATE())) AS LastUserUpdate,
        CASE 
            WHEN s.user_seeks + s.user_scans > 0 
            THEN CAST(s.user_seeks AS DECIMAL(10,4)) / (s.user_seeks + s.user_scans)
            ELSE 0 
        END AS UsageRatio
    FROM sys.dm_db_index_usage_stats s
    JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
    WHERE s.object_id IS NOT NULL;

    SELECT * FROM Practice_IndexUsage ORDER BY UserSeeks + UserScans DESC LIMIT 20;
END',
    @on_success_action = 1,
    @on_fail_action = 2;

EXEC msdb.dbo.sp_add_jobserver 
    @job_name = N'Practice_Index_Usage',
    @server_name = N'(local)';

-- Schedule: Every hour
EXEC msdb.dbo.sp_add_schedule 
    @freq_type = 4, -- Weekly
    @freq_interval = 1, -- Every day
    @freq_subday_type = 4, -- Every hour
    @freq_subday_interval = 1;

PRINT 'Practice environment setup complete!';
PRINT '';
PRINT 'Summary of created jobs:';
PRINT '';
PRINT 'Application Jobs (Enabled):';
PRINT '  - SalesApp_Daily_Report: Daily sales summaries at 9 AM';
PRINT '  - WarehouseApp_Inventory_Alert: Inventory checks every 4 hours';
PRINT '  - CSApp_Order_Processing: Order processing every hour (business hours)';
PRINT '  - ExecutiveApp_Dashboard_Refresh: Dashboard updates every 6 hours';
PRINT '  - HRApp_Employee_Activity: Employee activity every 3 hours';
PRINT '';
PRINT 'Practice Jobs (Enabled):';
PRINT '  - Practice_Query_Pattern_Analysis: Query pattern analysis at midnight';
PRINT '  - Practice_Lock_Monitor: Lock monitoring every 30 minutes';
PRINT '  - Practice_Index_Usage: Index usage tracking hourly';
PRINT '';
PRINT 'Practice Jobs (Disabled for safety):';
PRINT '  - Practice_Performance_Stress: Performance stress testing (enable manually)';
PRINT '';
PRINT 'To enable the performance stress job:';
PRINT '  EXEC msdb.dbo.sp_update_job @job_name = ''Practice_Performance_Stress'', @enabled = 1;';

GO
