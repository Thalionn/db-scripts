-- ============================================================================
-- Script: undo_usage.sql
-- Purpose: Undo tablespace monitoring and retention analysis
-- Usage:   Run before large batch jobs to verify undo sufficiency
-- Notes:   Tune UNDO_RETENTION based on results
-- ============================================================================

SET LINESIZE 160 PAGESIZE 50
COLUMN tablespace_name FORMAT A20
COLUMN total_mb FORMAT 999,999,999
COLUMN used_mb FORMAT 999,999,999
COLUMN tuned_retention FORMAT 999,999

SELECT 
    u.tablespace_name,
    df.total_mb,
    NVL(us.used_mb, 0) AS used_mb,
    ROUND(NVL(us.used_mb, 0) / df.total_mb * 100, 2) AS used_pct,
    t.undo_retention,
    t.tuned_undoretention AS tuned_retention,
    CASE 
        WHEN t.tuned_undoretention < t.undo_retention THEN 'BELOW TARGET'
        ELSE 'OK'
    END AS retention_status
FROM (
    SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS total_mb
    FROM dba_data_files
    WHERE tablespace_name LIKE 'UNDOTBS%' OR tablespace_name = 'SYSAUX'
    GROUP BY tablespace_name
) df
JOIN dba_tablespaces t ON df.tablespace_name = t.tablespace_name
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS used_mb
    FROM v$rollstat
    GROUP BY tablespace_name
) us ON df.tablespace_name = us.tablespace_name
WHERE t.contents = 'UNDO';
