-- ============================================================================
-- Script: table_size.sql
-- Purpose: Storage consumption by table (including indexes)
-- Usage:   Identify largest tables for partition planning
-- Notes:   Run as superuser or table owner for complete results
-- ============================================================================

SELECT 
    schemaname,
    relname AS table_name,
    n_live_tup AS row_count,
    n_dead_tup AS dead_rows,
    pg_size_pretty(pg_total_relation_size(schemaname || '.' || relname)) AS total_size,
    pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) AS table_size,
    pg_size_pretty(pg_indexes_size(schemaname || '.' || relname)) AS index_size,
    ROUND(n_dead_tup::numeric / NULLIF(n_live_tup + n_dead_tup, 0) * 100, 2) AS dead_tuple_pct
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname || '.' || relname) DESC
LIMIT 30;
