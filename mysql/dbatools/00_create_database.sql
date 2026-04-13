-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- MySQL DBATools Database Setup
-- Run as root

CREATE DATABASE IF NOT EXISTS dbatools;
USE dbatools;

-- Grant privileges to dbatools user (adjust as needed)
-- CREATE USER IF NOT EXISTS 'dbatools'@'localhost' IDENTIFIED BY 'password';
-- GRANT ALL PRIVILEGES ON dbatools.* TO 'dbatools'@'localhost';

PROMPT DBATools database created.
PROMPT Next: Run 01_tables.sql
