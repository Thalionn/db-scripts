-- ============================================================================
-- Script: temp_usage.sql
-- Purpose: Temporary tablespace consumption and sort activity
-- Usage:   Check when TEMP fills up or sorts are spilling to disk
-- Notes:   High allocated vs used indicates fragmentation
-- ============================================================================

SET LINESIZE 150 PAGESIZE 50
COLUMN tablespace_name FORMAT A20
COLUMN allocated_mb FORMAT 999,999,999
COLUMN used_mb FORMAT 999,999,999
COLUMN free_mb FORMAT 999,999,999

SELECT 
    t.tablespace_name,
    t.allocated_mb,
    NVL(s.used_mb, 0) AS used_mb,
    t.allocated_mb - NVL(s.used_mb, 0) AS free_mb,
    ROUND(NVL(s.used_mb, 0) / t.allocated_mb * 100, 2) AS used_pct
FROM (
    SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS allocated_mb
    FROM dba_temp_files
    GROUP BY tablespace_name
) t
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes_used) / 1024 / 1024 AS used_mb
    FROM v$tempseg_usage
    GROUP BY tablespace_name
) s ON t.tablespace_name = s.tablespace_name
ORDER BY used_pct DESC;
