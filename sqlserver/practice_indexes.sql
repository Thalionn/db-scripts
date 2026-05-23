-- ============================================================================
-- Script: practice_indexes.sql
-- Purpose: Create indexes for PracticeDB performance
-- Usage:   Run after practice_environment_setup.sql
-- Notes:   Improves query performance; drop if PracticeDB is removed
-- ============================================================================

USE PracticeDB;
GO

CREATE INDEX IX_Orders_CustomerID ON Sales.Orders(CustomerID) INCLUDE (OrderDate, Status, TotalAmount);
GO

CREATE INDEX IX_Orders_OrderDate ON Sales.Orders(OrderDate, CustomerID) INCLUDE (Status, ShipDate);
GO

CREATE INDEX IX_Customers_CityState ON Sales.Customers(City, State) INCLUDE (Email);
GO

CREATE INDEX IX_Products_Category ON Sales.Products(Category) INCLUDE (StockQuantity, ReorderPoint);
GO

CREATE INDEX IX_Employees_Department ON HumanResources.Employees(Department) INCLUDE (LastName, FirstName);
GO

CREATE CLUSTERED INDEX CX_InventoryLog_LogID ON Production.InventoryLog(LogID);
GO

PRINT 'Indexes created successfully!';
PRINT '';
PRINT 'Tip: Add more sample data and consider additional indexes based on query patterns.';
