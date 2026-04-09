-- Oracle: Table Space Usage
-- Usage: Monitor tablespace utilization

SELECT 
    tablespace_name,
    ROUND((1 - (b.bytes / a.bytes)) * 100, 2) AS used_pct,
    CASE 
        WHEN (1 - (b.bytes / a.bytes)) * 100 > 90 THEN 'CRITICAL'
        WHEN (1 - (b.bytes / a.bytes)) * 100 > 80 THEN 'WARNING'
        ELSE 'OK'
    END AS status
FROM dba_tablespace_usage_metrics a
JOIN dba_tablespace_quota b ON a.tablespace_name = b.tablespace_name;