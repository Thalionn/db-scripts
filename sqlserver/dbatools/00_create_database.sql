-- ============================================================================
-- Script: 00_create_database.sql
-- Purpose: Create DBATools monitoring database
-- Usage:   Run as sysadmin on each SQL Server instance
-- Notes:   Creates database with optimized defaults for logging
-- ============================================================================

USE master;
GO

IF DB_ID('DBATools') IS NOT NULL
BEGIN
    ALTER DATABASE DBATools SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE DBATools;
END
GO

CREATE DATABASE DBATools;
GO

ALTER DATABASE DBATools 
MODIFY FILE (NAME = 'DBATools', SIZE = 100MB, MAXSIZE = 10GB, FILEGROWTH = 100MB);

ALTER DATABASE DBATools 
MODIFY FILE (NAME = 'DBATools_log', SIZE = 50MB, MAXSIZE = 2GB, FILEGROWTH = 50MB);
GO

ALTER DATABASE DBATools SET RECOVERY SIMPLE;
GO

USE DBATools;
GO

-- Create schema for organization
CREATE SCHEMA dba AUTHORIZATION dbo;
GO

PRINT 'DBATools database created successfully.';
