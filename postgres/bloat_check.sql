-- ============================================================================
-- Script: bloat_check.sql
-- Purpose: Detect bloated tables and indexes requiring VACUUM
-- Usage:   Schedule VACUUM ANALYZE on high-bloat objects
-- Notes:   Assumes pgstattuple extension is available
-- ============================================================================

SELECT 
    schemaname,
    tablename,
    tup_count,
    pg_size_pretty(tup_len) AS physical_size,
    pg_size_pretty(free_space) AS free_space,
    CASE 
        WHEN free_space > 0 AND tup_len > 0 
        THEN ROUND((free_space::numeric / tup_len) * 100, 2)
        ELSE 0 
    END AS bloat_ratio,
    CASE 
        WHEN free_space > 0 AND tup_len > 0 
             AND (free_space::numeric / tup_len) * 100 > 20 THEN 'CLEANUP NEEDED'
        ELSE 'OK'
    END AS status
FROM pg_stat_user_tables t
JOIN LATERAL pgstattuple(t.schemaname || '.' . t.relname) s ON true
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY bloat_ratio DESC NULLS LAST
LIMIT 20;
