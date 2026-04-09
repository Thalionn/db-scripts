-- ============================================================================
-- Script: index_usage.sql
-- Purpose: Index usage statistics and unused indexes
-- Usage:   Drop unused indexes to reduce write overhead
-- Notes:   High idx_scan with low usage may indicate query plan issues
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(schemaname || '.' || indexname)) AS index_size,
    CASE 
        WHEN idx_scan = 0 THEN 'UNUSED - CONSIDER DROP'
        WHEN idx_scan < 100 THEN 'LOW USAGE'
        ELSE 'ACTIVE'
    END AS status
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY idx_scan ASC NULLS FIRST, pg_relation_size(schemaname || '.' || indexname) DESC;
