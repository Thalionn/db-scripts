-- ============================================================================
-- Script: duplicate_indexes.sql
-- Purpose: Find duplicate/redundant indexes
-- Usage:   Run during low-traffic periods on large tables
-- Notes:   Review carefully before dropping - consider foreign keys
-- ============================================================================

SELECT 
    t.tablename,
    t.schemaname,
    i.indexname,
    i.indexdef,
    pg_size_pretty(pg_relation_size(n.nspname || '.' || i.indexname::regclass)) AS index_size,
    s.idx_scan,
    s.idx_tup_read,
    s.idx_tup_fetch
FROM pg_indexes i
JOIN pg_stat_user_indexes s ON i.indexname = s.indexname AND i.tablename = s.tablename
JOIN pg_namespace n ON i.schemaname = n.nspname
JOIN pg_tables t ON t.tablename = i.tablename AND t.schemaname = i.schemaname
WHERE t.schemaname NOT IN ('pg_catalog', 'information_schema')
  AND i.indexname NOT LIKE '%pkey%'
  AND i.indexname NOT LIKE '%unique%'
ORDER BY pg_relation_size(n.nspname || '.' || i.indexname::regclass) DESC;
