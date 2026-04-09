-- ============================================================================
-- Script: wait_events.sql
-- Purpose: Top wait events indicating performance bottlenecks
-- Usage:   Compare against baseline; spikes indicate issues
-- Notes:   Focus on events with high time_waited deltas
-- ============================================================================

SET LINESIZE 150 PAGESIZE 50
COLUMN event FORMAT A50
COLUMN total_waits FORMAT 999,999,999
COLUMN time_waited FORMAT 999,999,999
COLUMN avg_wait_ms FORMAT 9,999.99

SELECT 
    e.event,
    e.total_waits,
    e.total_timeouts,
    e.time_waited,
    ROUND(e.average_wait * 10, 2) AS avg_wait_cs,
    ROUND(e.average_wait / 100, 2) AS avg_wait_ms
FROM v$system_event e
JOIN v$event_name n ON e.event_id = n.event_id
WHERE n.wait_class != 'Idle'
  AND e.total_waits > 100
ORDER BY e.time_waited DESC
FETCH FIRST 20 ROWS ONLY;
