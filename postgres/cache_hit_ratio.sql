-- ============================================================================
-- Script: cache_hit_ratio.sql
-- Purpose: Buffer cache efficiency metrics
-- Usage:   Compare to baseline; low ratios indicate memory pressure
-- Notes:   Target: 99%+ for OLTP, 90%+ for analytical workloads
-- ============================================================================

SELECT 
    schemaname,
    relname AS table_name,
    heap_blks_hit,
    heap_blks_read,
    heap_blks_hit + heap_blks_read AS total_blks,
    ROUND(
        (heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0)) * 100, 
        2
    ) AS cache_hit_ratio,
    idx_blks_hit,
    idx_blks_read,
    ROUND(
        (idx_blks_hit::numeric / NULLIF(idx_blks_hit + idx_blks_read, 0)) * 100, 
        2
    ) AS idx_cache_ratio,
    pg_size_pretty(pg_relation_size(schemaname || '.' || relname)) AS table_size
FROM pg_statio_user_tables
WHERE heap_blks_read > 0
ORDER BY (heap_blks_hit::numeric / NULLIF(heap_blks_hit + heap_blks_read, 0)) ASC
LIMIT 25;
