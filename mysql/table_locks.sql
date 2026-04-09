-- ============================================================================
-- Script: table_locks.sql
-- Purpose: Table-level lock contention
-- Usage:   Identify hot tables causing contention
-- Notes:   High Table_locks_waited vs Table_locks_immediate ratio is bad
-- ============================================================================

SELECT 
    OBJECT_SCHEMA AS database_name,
    OBJECT_NAME AS table_name,
    COUNT_READ AS total_reads,
    COUNT_WRITE AS total_writes,
    SUM_TIMER_WAIT / 1000000000000 AS total_wait_sec,
    COUNT_STAR AS lock_count,
    ROUND(SUM_TIMER_WAIT / 1000000000000 / NULLIF(COUNT_STAR, 0), 6) AS avg_wait_sec
FROM performance_schema.objects_summary_global_by_type
WHERE OBJECT_TYPE = 'TABLE'
  AND OBJECT_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema')
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 30;
