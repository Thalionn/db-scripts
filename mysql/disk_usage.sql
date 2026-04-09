-- ============================================================================
-- Script: disk_usage.sql
-- Purpose: Database and table storage consumption
-- Usage:   Identify largest databases/tables for cleanup
-- Notes:   Run as MySQL admin user
-- ============================================================================

SELECT 
    table_schema AS database_name,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS total_mb,
    ROUND(SUM(data_length) / 1024 / 1024, 2) AS data_mb,
    ROUND(SUM(index_length) / 1024 / 1024, 2) AS index_mb,
    COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema NOT IN (
    'information_schema', 
    'performance_schema', 
    'mysql', 
    'sys'
)
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY total_mb DESC;
