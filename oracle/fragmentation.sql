-- ============================================================================
-- Script: fragmentation.sql
-- Purpose: Detect table and index fragmentation
-- Usage:   Quarterly health check; schedule reorganization if needed
-- Notes:   High ratio indicates CHR or shrink needed
-- ============================================================================

SET LINESIZE 200 PAGESIZE 50
COLUMN owner FORMAT A20
COLUMN table_name FORMAT A35
COLUMN chain_cnt FORMAT 999,999,999
COLUMN num_rows FORMAT 999,999,999
COLUMN chain_pct FORMAT 999.99

SELECT 
    owner,
    table_name,
    num_rows,
    chain_cnt,
    ROUND(chain_cnt / NULLIF(num_rows, 0) * 100, 2) AS chain_pct,
    CASE 
        WHEN ROUND(chain_cnt / NULLIF(num_rows, 0) * 100, 2) > 10 THEN 'REBUILD NEEDED'
        WHEN ROUND(chain_cnt / NULLIF(num_rows, 0) * 100, 2) > 5 THEN 'MONITOR'
        ELSE 'OK'
    END AS status
FROM dba_tables
WHERE owner NOT IN ('SYS', 'SYSTEM')
  AND chain_cnt > 0
  AND num_rows > 10000
ORDER BY chain_cnt DESC;
