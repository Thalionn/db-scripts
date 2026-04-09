-- ============================================================================
-- Script: generate_health_check.sql
-- Purpose: Generate complete health check report
-- Usage:   Run weekly/monthly for documentation
-- Notes:   Output to file for audit trail
-- ============================================================================

-- ============================================================================
-- OUTPUT: System Overview
-- ============================================================================

-- PostgreSQL
-- SELECT now() AS report_time;
-- SELECT * FROM pg_stat_database WHERE datname = current_database();

-- Oracle
-- SELECT SYSDATE FROM DUAL;
-- SELECT * FROM v$instance;
-- SELECT * FROM v$database;

-- MySQL
-- SELECT NOW();
-- SELECT * FROM information_schema.GLOBAL_STATUS WHERE VARIABLE_NAME IN ('UPTIME', 'THREADS_CONNECTED');

-- SQL Server
-- SELECT GETDATE();
-- SELECT @@VERSION;
-- SELECT * FROM sys.databases;
