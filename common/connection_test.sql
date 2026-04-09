-- ============================================================================
-- Script: connection_test.sql
-- Purpose: Basic connectivity and version verification
-- Usage:   Run on any platform to verify access and basic function
-- Notes:   Copy section for your specific database below
-- ============================================================================

-- PostgreSQL
-- SELECT version();
-- SELECT current_user, current_database();
-- SELECT NOW();

-- MySQL
-- SELECT VERSION();
-- SELECT CURRENT_USER, DATABASE();
-- SELECT NOW();

-- Oracle
-- SELECT * FROM v$version;
-- SELECT USER, SYS_CONTEXT('USERENV', 'DB_NAME') FROM DUAL;
-- SELECT SYSDATE FROM DUAL;

-- SQL Server
-- SELECT @@VERSION;
-- SELECT SYSTEM_USER, DB_NAME();
-- SELECT GETDATE();
