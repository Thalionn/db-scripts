-- =============================================
-- SQL Server Practice Environment Setup Script
-- Creates a self-contained PracticeDB with simulated
-- users, data, and scheduled jobs for practice
-- =============================================

USE master;
GO

IF DB_ID('PracticeDB') IS NOT NULL
BEGIN
    ALTER DATABASE PracticeDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE PracticeDB;
END
GO

CREATE DATABASE PracticeDB;
GO

ALTER DATABASE PracticeDB SET RECOVERY SIMPLE;
GO

USE PracticeDB;
GO

-- =============================================
-- SECTION 0: Create Logins and Database Users
-- =============================================

PRINT 'Creating logins and users...';

DECLARE @PracticePassword NVARCHAR(128) = N'Practice123!';

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'SalesAppLogin')
    CREATE LOGIN [SalesAppLogin] WITH PASSWORD = @PracticePassword;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'WarehouseAppLogin')
    CREATE LOGIN [WarehouseAppLogin] WITH PASSWORD = @PracticePassword;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'AnalyticsAppLogin')
    CREATE LOGIN [AnalyticsAppLogin] WITH PASSWORD = @PracticePassword;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'HRAppLogin')
    CREATE LOGIN [HRAppLogin] WITH PASSWORD = @PracticePassword;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'CSAppLogin')
    CREATE LOGIN [CSAppLogin] WITH PASSWORD = @PracticePassword;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'ExecutiveAppLogin')
    CREATE LOGIN [ExecutiveAppLogin] WITH PASSWORD = @PracticePassword;
GO

-- Create schemas
CREATE SCHEMA Sales AUTHORIZATION dbo;
GO

CREATE SCHEMA Production AUTHORIZATION dbo;
GO

CREATE SCHEMA HumanResources AUTHORIZATION dbo;
GO

-- Create users
CREATE USER [SalesApp] FOR LOGIN [SalesAppLogin];
CREATE USER [WarehouseApp] FOR LOGIN [WarehouseAppLogin];
CREATE USER [AnalyticsApp] FOR LOGIN [AnalyticsAppLogin];
CREATE USER [HRApp] FOR LOGIN [HRAppLogin];
CREATE USER [CSApp] FOR LOGIN [CSAppLogin];
CREATE USER [ExecutiveApp] FOR LOGIN [ExecutiveAppLogin];
GO

-- Grant permissions
GRANT SELECT, INSERT, UPDATE ON SCHEMA::Sales TO [SalesApp];
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Production TO [WarehouseApp];
GRANT SELECT ON SCHEMA::Sales TO [AnalyticsApp];
GRANT SELECT ON SCHEMA::Production TO [AnalyticsApp];
GRANT SELECT, INSERT, UPDATE ON SCHEMA::HumanResources TO [HRApp];
GRANT SELECT ON SCHEMA::Sales TO [CSApp];
GRANT SELECT ON SCHEMA::Production TO [CSApp];
GRANT SELECT ON SCHEMA::Sales TO [ExecutiveApp];
GRANT SELECT ON SCHEMA::Production TO [ExecutiveApp];
GO

-- =============================================
-- SECTION 1: Create Practice Tables
-- =============================================

PRINT 'Creating practice tables...';

CREATE TABLE Sales.Products (
    ProductID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(100) NOT NULL,
    Category NVARCHAR(50),
    UnitPrice DECIMAL(10,2),
    StockQuantity INT DEFAULT 0,
    ReorderPoint INT DEFAULT 10
);

CREATE TABLE Sales.Customers (
    CustomerID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Email NVARCHAR(100),
    Phone NVARCHAR(20),
    City NVARCHAR(50),
    State NVARCHAR(2),
    IsActive BIT DEFAULT 1
);

CREATE TABLE Sales.Orders (
    OrderID INT IDENTITY(1,1) PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATETIME DEFAULT GETDATE(),
    ShipDate DATETIME,
    Status NVARCHAR(20) DEFAULT 'Pending',
    TotalAmount DECIMAL(12,2),
    FOREIGN KEY (CustomerID) REFERENCES Sales.Customers(CustomerID)
);

CREATE TABLE Sales.OrderDetails (
    DetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT,
    UnitPrice DECIMAL(10,2),
    FOREIGN KEY (OrderID) REFERENCES Sales.Orders(OrderID),
    FOREIGN KEY (ProductID) REFERENCES Sales.Products(ProductID)
);

CREATE TABLE Production.InventoryLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    ProductID INT,
    ChangeType NVARCHAR(20),
    QuantityChange INT,
    ChangeDate DATETIME DEFAULT GETDATE(),
    Notes NVARCHAR(200)
);

CREATE TABLE HumanResources.Employees (
    EmployeeID INT IDENTITY(1,1) PRIMARY KEY,
    FirstName NVARCHAR(50),
    LastName NVARCHAR(50),
    Department NVARCHAR(50),
    JobTitle NVARCHAR(50),
    HireDate DATE,
    VacationHours INT DEFAULT 40,
    SickHours INT DEFAULT 40
);
GO

-- =============================================
-- SECTION 2: Seed Sample Data
-- =============================================

PRINT 'Seeding sample data...';

INSERT INTO Sales.Products (ProductName, Category, UnitPrice, StockQuantity, ReorderPoint) VALUES
('Widget A', 'Widgets', 12.99, 150, 20),
('Widget B', 'Widgets', 24.50, 8, 15),
('Gadget X', 'Gadgets', 45.00, 200, 30),
('Gadget Y', 'Gadgets', 32.75, 5, 10),
('Connector Pro', 'Connectors', 8.50, 500, 100),
('Adapter Plus', 'Adapters', 15.99, 75, 25),
('Cable Standard', 'Cables', 5.99, 300, 50),
('Cable Premium', 'Cables', 9.99, 12, 20),
('Power Supply', 'Electronics', 89.99, 40, 10),
('Monitor Stand', 'Accessories', 29.99, 60, 15);

INSERT INTO Sales.Customers (FirstName, LastName, Email, Phone, City, State) VALUES
('John', 'Smith', 'john.smith@email.com', '555-0101', 'Seattle', 'WA'),
('Jane', 'Doe', 'jane.doe@email.com', '555-0102', 'Portland', 'OR'),
('Bob', 'Johnson', 'bob.j@email.com', '555-0103', 'Austin', 'TX'),
('Alice', 'Williams', 'alice.w@email.com', '555-0104', 'Denver', 'CO'),
('Charlie', 'Brown', 'charlie.b@email.com', '555-0105', 'Chicago', 'IL'),
('Diana', 'Prince', 'diana.p@email.com', '555-0106', 'New York', 'NY'),
('Eve', 'Davis', 'eve.d@email.com', '555-0107', 'San Francisco', 'CA'),
('Frank', 'Miller', 'frank.m@email.com', '555-0108', 'Boston', 'MA'),
('Grace', 'Wilson', 'grace.w@email.com', '555-0109', 'Miami', 'FL'),
('Henry', 'Taylor', 'henry.t@email.com', '555-0110', 'Atlanta', 'GA');

INSERT INTO Sales.Orders (CustomerID, OrderDate, ShipDate, Status, TotalAmount) VALUES
(1, '2024-01-15', '2024-01-17', 'Shipped', 58.48),
(2, '2024-01-16', NULL, 'Pending', 134.99),
(3, '2024-01-17', '2024-01-18', 'Shipped', 45.00),
(4, '2024-01-18', '2024-01-20', 'Delivered', 179.97),
(5, '2024-01-19', NULL, 'Processing', 32.75),
(6, '2024-01-20', NULL, 'Pending', 89.99),
(7, '2024-01-21', '2024-01-22', 'Shipped', 24.50),
(1, '2024-02-01', NULL, 'In Process', 67.98),
(3, '2024-02-03', '2024-02-05', 'Delivered', 155.48),
(8, '2024-02-05', NULL, 'Approved', 29.99);

INSERT INTO Sales.OrderDetails (OrderID, ProductID, Quantity, UnitPrice) VALUES
(1, 1, 2, 12.99), (1, 5, 2, 8.50), (1, 3, 1, 45.00),
(2, 9, 1, 89.99), (2, 2, 1, 24.50), (2, 8, 1, 9.99),
(3, 3, 1, 45.00),
(4, 10, 3, 29.99), (4, 6, 2, 15.99), (4, 1, 2, 12.99),
(5, 4, 1, 32.75),
(6, 9, 1, 89.99),
(7, 2, 1, 24.50),
(8, 1, 2, 12.99), (8, 5, 3, 8.50), (8, 7, 2, 5.99),
(9, 9, 1, 89.99), (9, 3, 1, 45.00), (9, 8, 1, 9.99), (9, 7, 1, 5.99),
(10, 10, 1, 29.99);

INSERT INTO HumanResources.Employees (FirstName, LastName, Department, JobTitle, HireDate, VacationHours, SickHours) VALUES
('Sarah', 'Connor', 'Sales', 'Sales Manager', '2020-03-15', 80, 40),
('Mike', 'Ross', 'Warehouse', 'Inventory Manager', '2019-07-01', 120, 32),
('Lisa', 'Park', 'Analytics', 'Data Analyst', '2021-01-10', 60, 48),
('Tom', 'Hanks', 'HR', 'HR Specialist', '2018-11-20', 160, 56),
('Amy', 'Chen', 'Sales', 'Account Executive', '2022-05-12', 40, 40),
('James', 'Bond', 'Warehouse', 'Shipping Clerk', '2023-02-28', 20, 40);

INSERT INTO Production.InventoryLog (ProductID, ChangeType, QuantityChange, Notes) VALUES
(2, 'RESTOCK', -2, 'Low stock reorder'),
(4, 'RESTOCK', -5, 'Below reorder point'),
(8, 'RESTOCK', -8, 'Low stock alert triggered'),
(1, 'SALE', 2, 'Order #1'),
(5, 'SALE', 2, 'Order #1'),
(9, 'SALE', 1, 'Order #2'),
(2, 'SALE', 1, 'Order #2');
GO

-- =============================================
-- SECTION 3: Create Simulated Application Jobs
-- =============================================

PRINT 'Creating application simulation jobs...';

-- Job 1: Daily Sales Report
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'SalesApp_Daily_Report')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'SalesApp_Daily_Report',
        @enabled = 1,
        @description = N'Generates daily sales summary';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'SalesApp_Daily_Report',
        @step_name = N'Generate Sales Summary',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
-- Create daily sales summary table
IF OBJECT_ID(''dbo.SalesApp_Daily_SalesSummary'') IS NOT NULL
    DROP TABLE dbo.SalesApp_Daily_SalesSummary;

CREATE TABLE dbo.SalesApp_Daily_SalesSummary (
    ReportDate DATE PRIMARY KEY,
    TotalSales DECIMAL(18,2),
    OrderCount INT,
    UniqueCustomers INT,
    TopProduct NVARCHAR(50)
);

INSERT INTO dbo.SalesApp_Daily_SalesSummary (ReportDate, TotalSales, OrderCount, UniqueCustomers, TopProduct)
SELECT 
    CAST(GETDATE() AS DATE) AS ReportDate,
    SUM(TotalAmount) AS TotalSales,
    COUNT(*) AS OrderCount,
    COUNT(DISTINCT CustomerID) AS UniqueCustomers,
    (SELECT TOP 1 p.ProductName
     FROM Sales.OrderDetails od
     JOIN Sales.Products p ON od.ProductID = p.ProductID
     GROUP BY p.ProductName
     ORDER BY SUM(od.Quantity * od.UnitPrice) DESC) AS TopProduct
FROM Sales.Orders
WHERE CAST(OrderDate AS DATE) = CAST(GETDATE() AS DATE);

SELECT * FROM dbo.SalesApp_Daily_SalesSummary;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'SalesApp_Daily_Report',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'SalesApp_Daily_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 090000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'SalesApp_Daily_Report',
        @schedule_name = N'SalesApp_Daily_Schedule';
END

-- Job 2: Inventory Reorder Alert
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'WarehouseApp_Inventory_Alert')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'WarehouseApp_Inventory_Alert',
        @enabled = 1,
        @description = N'Monitors inventory levels and alerts on low stock';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'WarehouseApp_Inventory_Alert',
        @step_name = N'Check Inventory Levels',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.WarehouseApp_LowStockAlert'') IS NOT NULL
    DROP TABLE dbo.WarehouseApp_LowStockAlert;

CREATE TABLE dbo.WarehouseApp_LowStockAlert (
    AlertID INT IDENTITY(1,1) PRIMARY KEY,
    ProductName NVARCHAR(50),
    CurrentStock INT,
    ReorderPoint INT,
    ShortageAmount INT,
    LastChecked DATETIME DEFAULT GETDATE()
);

INSERT INTO dbo.WarehouseApp_LowStockAlert (ProductName, CurrentStock, ReorderPoint, ShortageAmount)
SELECT 
    p.ProductName,
    p.StockQuantity AS CurrentStock,
    p.ReorderPoint,
    p.ReorderPoint - p.StockQuantity AS ShortageAmount
FROM Sales.Products p
WHERE p.StockQuantity < p.ReorderPoint
ORDER BY ShortageAmount DESC;

SELECT * FROM dbo.WarehouseApp_LowStockAlert;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'WarehouseApp_Inventory_Alert',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'WarehouseApp_Inventory_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 4,
        @active_start_time = 000000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'WarehouseApp_Inventory_Alert',
        @schedule_name = N'WarehouseApp_Inventory_Schedule';
END

-- Job 3: Customer Order Processing
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'CSApp_Order_Processing')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'CSApp_Order_Processing',
        @enabled = 1,
        @description = N'Simulates customer order processing';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'CSApp_Order_Processing',
        @step_name = N'Process Pending Orders',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.CSApp_OrderProcessingLog'') IS NOT NULL
    DROP TABLE dbo.CSApp_OrderProcessingLog;

CREATE TABLE dbo.CSApp_OrderProcessingLog (
    LogID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT,
    CustomerName NVARCHAR(100),
    TotalDue DECIMAL(18,2),
    StatusChange NVARCHAR(50),
    ProcessedAt DATETIME DEFAULT GETDATE()
);

INSERT INTO dbo.CSApp_OrderProcessingLog (OrderID, CustomerName, TotalDue, StatusChange)
SELECT TOP 5
    o.OrderID,
    c.FirstName + '' '' + c.LastName AS CustomerName,
    o.TotalAmount,
    CASE WHEN o.Status = ''In Process'' THEN ''Completed'' ELSE ''Status Updated'' END
FROM Sales.Orders o
JOIN Sales.Customers c ON o.CustomerID = c.CustomerID
WHERE o.Status IN (''In Process'', ''Approved'')
ORDER BY o.OrderDate DESC;

SELECT * FROM dbo.CSApp_OrderProcessingLog;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'CSApp_Order_Processing',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'CSApp_Order_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 1,
        @active_start_time = 090000,
        @active_end_time = 180000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'CSApp_Order_Processing',
        @schedule_name = N'CSApp_Order_Schedule';
END

-- Job 4: Executive Dashboard Refresh
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'ExecutiveApp_Dashboard_Refresh')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'ExecutiveApp_Dashboard_Refresh',
        @enabled = 1,
        @description = N'Refreshes executive dashboard metrics';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'ExecutiveApp_Dashboard_Refresh',
        @step_name = N'Update Executive Metrics',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.ExecutiveApp_Metrics'') IS NOT NULL
    DROP TABLE dbo.ExecutiveApp_Metrics;

CREATE TABLE dbo.ExecutiveApp_Metrics (
    MetricID INT IDENTITY(1,1) PRIMARY KEY,
    MetricName NVARCHAR(50),
    CurrentValue DECIMAL(18,2),
    PreviousValue DECIMAL(18,2),
    ChangePercent DECIMAL(5,2),
    LastUpdated DATETIME DEFAULT GETDATE()
);

INSERT INTO dbo.ExecutiveApp_Metrics (MetricName, CurrentValue, PreviousValue)
VALUES
    (''TotalRevenue'', (SELECT SUM(TotalAmount) FROM Sales.Orders), 0),
    (''ActiveCustomers'', (SELECT COUNT(DISTINCT CustomerID) FROM Sales.Orders WHERE OrderDate >= DATEADD(MONTH, -1, GETDATE())), 0),
    (''AvgOrderValue'', (SELECT AVG(TotalAmount) FROM Sales.Orders), 0),
    (''TotalProducts'', (SELECT COUNT(*) FROM Sales.Products), 0),
    (''LowStockItems'', (SELECT COUNT(*) FROM Sales.Products WHERE StockQuantity < ReorderPoint), 0);

UPDATE dbo.ExecutiveApp_Metrics
SET ChangePercent = CASE WHEN PreviousValue > 0 THEN (CurrentValue - PreviousValue) / PreviousValue * 100 ELSE 0 END;

SELECT * FROM dbo.ExecutiveApp_Metrics;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'ExecutiveApp_Dashboard_Refresh',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'ExecutiveApp_Dashboard_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 6,
        @active_start_time = 000000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'ExecutiveApp_Dashboard_Refresh',
        @schedule_name = N'ExecutiveApp_Dashboard_Schedule';
END

-- Job 5: HR Employee Activity Monitor
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'HRApp_Employee_Activity')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'HRApp_Employee_Activity',
        @enabled = 1,
        @description = N'Monitors employee activity and balances';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'HRApp_Employee_Activity',
        @step_name = N'Update Employee Activity',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.HRApp_EmployeeActivity'') IS NOT NULL
    DROP TABLE dbo.HRApp_EmployeeActivity;

CREATE TABLE dbo.HRApp_EmployeeActivity (
    ActivityID INT IDENTITY(1,1) PRIMARY KEY,
    EmployeeName NVARCHAR(100),
    Department NVARCHAR(50),
    JobTitle NVARCHAR(50),
    VacationHoursRemaining INT,
    SickHoursRemaining INT,
    LastActivity DATETIME,
    Status NVARCHAR(30)
);

INSERT INTO dbo.HRApp_EmployeeActivity (EmployeeName, Department, JobTitle, VacationHoursRemaining, SickHoursRemaining, LastActivity, Status)
SELECT 
    e.FirstName + '' '' + e.LastName AS EmployeeName,
    e.Department,
    e.JobTitle,
    e.VacationHours,
    e.SickHours,
    GETDATE() AS LastActivity,
    ''Active'' AS Status
FROM HumanResources.Employees e;

SELECT * FROM dbo.HRApp_EmployeeActivity;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'HRApp_Employee_Activity',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'HRApp_Employee_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 3,
        @active_start_time = 090000,
        @active_end_time = 180000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'HRApp_Employee_Activity',
        @schedule_name = N'HRApp_Employee_Schedule';
END

-- Job 6: Practice Lock Monitor
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'Practice_Lock_Monitor')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'Practice_Lock_Monitor',
        @enabled = 1,
        @description = N'Monitors lock contention and blocking';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'Practice_Lock_Monitor',
        @step_name = N'Check Locks',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.Practice_LockMonitor'') IS NOT NULL
    DROP TABLE dbo.Practice_LockMonitor;

CREATE TABLE dbo.Practice_LockMonitor (
    MonitorID INT IDENTITY(1,1) PRIMARY KEY,
    CheckTime DATETIME DEFAULT GETDATE(),
    TotalLocks INT,
    BlockedSessions INT,
    TopBlockingSession INT,
    LockDetails NVARCHAR(MAX)
);

INSERT INTO dbo.Practice_LockMonitor (TotalLocks, BlockedSessions, TopBlockingSession, LockDetails)
SELECT 
    COUNT(*) AS TotalLocks,
    SUM(CASE WHEN r.blocking_session_id > 0 THEN 1 ELSE 0 END) AS BlockedSessions,
    MAX(r.blocking_session_id) AS TopBlockingSession,
    (SELECT STRING_AGG(
        CAST(r.session_id AS VARCHAR) + '' blocked by '' + CAST(r.blocking_session_id AS VARCHAR),
        ''; '')
     FROM sys.dm_exec_requests r
     WHERE r.blocking_session_id > 0) AS LockDetails
FROM sys.dm_exec_requests r;

SELECT TOP 5 * FROM dbo.Practice_LockMonitor ORDER BY CheckTime DESC;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'Practice_Lock_Monitor',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'Practice_Lock_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 4,
        @freq_subday_interval = 30,
        @active_start_time = 000000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'Practice_Lock_Monitor',
        @schedule_name = N'Practice_Lock_Schedule';
END

-- Job 7: Index Usage Monitor
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'Practice_Index_Usage')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'Practice_Index_Usage',
        @enabled = 1,
        @description = N'Monitors index usage statistics';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'Practice_Index_Usage',
        @step_name = N'Update Index Usage',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
IF OBJECT_ID(''dbo.Practice_IndexUsage'') IS NOT NULL
    DROP TABLE dbo.Practice_IndexUsage;

CREATE TABLE dbo.Practice_IndexUsage (
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

INSERT INTO dbo.Practice_IndexUsage (TableName, IndexName, UserSeeks, UserScans, UserUpdates, 
                                    LastUserSeek, LastUserScan, LastUserUpdate, UsageRatio)
SELECT 
    OBJECT_NAME(s.object_id) AS TableName,
    i.name AS IndexName,
    s.user_seeks,
    s.user_scans,
    s.user_updates,
    s.last_user_seek,
    s.last_user_scan,
    s.last_user_update,
    CASE 
        WHEN s.user_seeks + s.user_scans > 0 
        THEN CAST(s.user_seeks AS DECIMAL(10,4)) / (s.user_seeks + s.user_scans)
        ELSE 0 
    END AS UsageRatio
FROM sys.dm_db_index_usage_stats s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.database_id = DB_ID()
  AND OBJECTPROPERTY(s.object_id, ''IsUserTable'') = 1;

SELECT TOP 20 * FROM dbo.Practice_IndexUsage ORDER BY UserSeeks + UserScans DESC;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'Practice_Index_Usage',
        @server_name = @@SERVERNAME;

    EXEC msdb.dbo.sp_add_schedule 
        @schedule_name = N'Practice_Index_Schedule',
        @freq_type = 4,
        @freq_interval = 1,
        @freq_subday_type = 8,
        @freq_subday_interval = 1,
        @active_start_time = 000000;

    EXEC msdb.dbo.sp_attach_schedule 
        @job_name = N'Practice_Index_Usage',
        @schedule_name = N'Practice_Index_Schedule';
END

-- Job 8: Performance Stress (disabled by default)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = 'Practice_Performance_Stress')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'Practice_Performance_Stress',
        @enabled = 0,
        @description = N'Simulates performance stress (DISABLED)';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'Practice_Performance_Stress',
        @step_name = N'Insert Test Data',
        @subsystem = N'TSQL',
        @database_name = N'PracticeDB',
        @command = N'
-- WARNING: Only enable for practice purposes!
DECLARE @batchSize INT = 1000;
DECLARE @totalRows INT = 50000;
DECLARE @counter INT = 0;

WHILE @counter < @totalRows
BEGIN
    INSERT INTO Sales.Orders (CustomerID, OrderDate, Status, TotalAmount)
    SELECT 
        ABS(CHECKSUM(NEWID())) % 10 + 1,
        DATEADD(DAY, ABS(CHECKSUM(NEWID())) % 365, ''2024-01-01''),
        ''Pending'',
        ABS(CHECKSUM(NEWID())) % 100000.00;

    SET @counter = @counter + @batchSize;
    WAITFOR DELAY ''00:00:01'';
END;';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'Practice_Performance_Stress',
        @server_name = @@SERVERNAME;
END

PRINT 'Practice environment setup complete!';
PRINT '';
PRINT 'Summary of created jobs:';
PRINT '';
PRINT 'Application Jobs (Enabled):';
PRINT '  - SalesApp_Daily_Report: Daily sales summaries at 9 AM';
PRINT '  - WarehouseApp_Inventory_Alert: Inventory checks every 4 hours';
PRINT '  - CSApp_Order_Processing: Order processing every hour (business hours)';
PRINT '  - ExecutiveApp_Dashboard_Refresh: Dashboard updates every 6 hours';
PRINT '  - HRApp_Employee_Activity: Employee activity every 3 hours (business hours)';
PRINT '';
PRINT 'Practice Jobs (Enabled):';
PRINT '  - Practice_Lock_Monitor: Lock monitoring every 30 minutes';
PRINT '  - Practice_Index_Usage: Index usage tracking hourly';
PRINT '';
PRINT 'Practice Jobs (Disabled for safety):';
PRINT '  - Practice_Performance_Stress: Performance stress testing (enable manually)';
PRINT '';
PRINT 'To enable the performance stress job:';
PRINT '  EXEC msdb.dbo.sp_update_job @job_name = ''Practice_Performance_Stress'', @enabled = 1;';
