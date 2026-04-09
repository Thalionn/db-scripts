-- ============================================================================
-- Script: wait_stats.sql
-- Purpose: Aggregated wait statistics for bottleneck analysis
-- Usage:   Compare to baseline; CXPACKET on high-CPU may need tuning
-- Notes:   Resets when instance restarts; capture baseline regularly
-- ============================================================================

SET NOCOUNT ON;

SELECT TOP 20
    wait_type,
    waiting_task_count,
    wait_time_ms,
    signal_wait_time_ms,
    wait_time_ms - signal_wait_time_ms AS resource_wait_ms,
    ROUND(wait_time_ms * 100.0 / NULLIF(SUM(wait_time_ms) OVER(), 0), 2) AS wait_pct,
    CASE 
        WHEN wait_type LIKE 'PAGEIOLATCH%' THEN 'I/O'
        WHEN wait_type LIKE 'LCK_M%' THEN 'LOCKS'
        WHEN wait_type LIKE 'PAGELATCH%' THEN 'LATCH'
        WHEN wait_type LIKE 'ASYNC%' THEN 'NETWORK'
        WHEN wait_type LIKE 'SOS%' THEN 'MEMORY'
        WHEN wait_type = 'CXPACKET' THEN 'PARALLELISM'
        ELSE 'OTHER'
    END AS category
FROM sys.dm_os_wait_stats
WHERE wait_time_ms > 0
  AND waiting_task_count > 0
  AND wait_type NOT IN (
      'SLEEP_TASK', 'BROKER_TASK_STOP', 'BROKER_TO_FLUSH',
      'SQLTRACE_BUFFER_FLUSH', 'CLR_AUTO_EVENT', 'LAZYWRITER_SLEEP',
      'XE_DISPATCHER_WAIT', 'REQUEST_FOR_DEADLOCK_SEARCH'
  )
ORDER BY wait_time_ms DESC;
