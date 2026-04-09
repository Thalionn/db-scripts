-- ============================================================================
-- Script: generate_refresh_stats.sql
-- Purpose: Generate statistics refresh commands for tables
-- Usage:   Run and copy output after large data loads
-- Notes:   Adjust table list and sample size as needed
-- ============================================================================

-- PostgreSQL
-- SELECT 'ANALYZE VERBOSE ' || schemaname || '.' || relname || ';'
-- FROM pg_stat_user_tables
-- WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
-- ORDER BY n_live_tup DESC;

-- Oracle
-- SELECT 'BEGIN DBMS_STATS.GATHER_TABLE_STATS(''' || OWNER || ''', ''' || TABLE_NAME || '''); END;' || CHR(10) || '/'
-- FROM DBA_TABLES
-- WHERE OWNER NOT IN ('SYS', 'SYSTEM')
--   AND NUM_ROWS > 10000
-- ORDER BY NUM_ROWS DESC;

-- MySQL
-- SELECT CONCAT('ANALYZE TABLE ', TABLE_SCHEMA, '.', TABLE_NAME, ';')
-- FROM information_schema.TABLES
-- WHERE TABLE_SCHEMA NOT IN ('information_schema', 'performance_schema', 'mysql')
--   AND TABLE_ROWS > 10000
-- ORDER BY TABLE_ROWS DESC;

-- SQL Server
-- SELECT 'UPDATE STATISTICS ' + s.name + '.' + t.name + ' WITH FULLSCAN;'
-- FROM sys.tables t
-- JOIN sys.schemas s ON t.schema_id = s.schema_id
-- WHERE t.is_ms_shipped = 0;
