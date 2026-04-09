-- ============================================================================
-- Script: tablespace_check.sql
-- Purpose: Tablespace utilization with alert thresholds
-- Usage:   Daily space monitoring, add to crontab for automated checks
-- Notes:   Thresholds: CRITICAL >90%, WARNING >80%
-- ============================================================================

SET LINESIZE 150 PAGESIZE 50
COLUMN tablespace_name FORMAT A25
COLUMN total_mb FORMAT 999,999,999
COLUMN used_mb FORMAT 999,999,999
COLUMN free_mb FORMAT 999,999,999
COLUMN used_pct FORMAT 999.99

SELECT 
    df.tablespace_name,
    df.total_mb,
    df.total_mb - NVL(fs.free_mb, 0) AS used_mb,
    NVL(fs.free_mb, 0) AS free_mb,
    ROUND((df.total_mb - NVL(fs.free_mb, 0)) / df.total_mb * 100, 2) AS used_pct,
    CASE 
        WHEN (df.total_mb - NVL(fs.free_mb, 0)) / df.total_mb * 100 >= 90 THEN 'CRITICAL'
        WHEN (df.total_mb - NVL(fs.free_mb, 0)) / df.total_mb * 100 >= 80 THEN 'WARNING'
        ELSE 'OK'
    END AS alert_status
FROM (
    SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN (
    SELECT tablespace_name, SUM(bytes) / 1024 / 1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs ON df.tablespace_name = fs.tablespace_name
ORDER BY used_pct DESC;
