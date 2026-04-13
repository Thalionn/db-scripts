-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- Oracle DBATools Views
-- Run as DBATOOLS user

CREATE OR REPLACE VIEW dba_v_current_waits AS
SELECT 
    wait_class,
    event_name,
    wait_count,
    time_waited_ms,
    ROUND(time_waited_ms * 100 / SUM(time_waited_ms) OVER(), 2) AS pct
FROM (
    SELECT 
        wait_class,
        event,
        wait_count,
        time_waited_ms
    FROM v$system_event
    WHERE wait_count > 0
      AND wait_class != 'Idle'
    ORDER BY time_waited_ms DESC
)
WHERE ROWNUM <= 20;

CREATE OR REPLACE VIEW dba_v_session_snapshots AS
SELECT 
    sample_time,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions,
    SUM(CASE WHEN status = 'WAITING' THEN 1 ELSE 0 END) AS waiting_sessions
FROM dba_session_snapshot
WHERE sample_time >= SYSTIMESTAMP - 1/24
GROUP BY sample_time
ORDER BY sample_time DESC;

CREATE OR REPLACE VIEW dba_v_tablespace_usage AS
SELECT 
    sample_time,
    tablespace_name,
    total_mb,
    used_mb,
    free_mb,
    pct_used,
    CASE 
        WHEN pct_used > 90 THEN 'CRITICAL'
        WHEN pct_used > 80 THEN 'WARNING'
        ELSE 'OK'
    END AS status
FROM dba_database_sizes
WHERE sample_time >= SYSTIMESTAMP - 1/24
ORDER BY pct_used DESC;

CREATE OR REPLACE VIEW dba_v_top_sql AS
SELECT TOP 10
    sql_id,
    sql_text,
    executions,
    ROUND(elapsed_time_ns / 1000000 / executions, 2) AS avg_time_ms,
    buffer_gets,
    disk_reads,
    ROUND(buffer_gets / executions, 0) AS avg_buffer_gets
FROM dba_sql_stats
WHERE sample_time >= SYSTIMESTAMP - 1/24
ORDER BY elapsed_time_ns DESC;

CREATE OR REPLACE VIEW dba_v_tablespace_history AS
SELECT 
    tablespace_name,
    MIN(sample_time) AS first_sample,
    MAX(sample_time) AS last_sample,
    MIN(used_mb) AS min_used_mb,
    MAX(used_mb) AS max_used_mb,
    MAX(used_mb) - MIN(used_mb) AS growth_mb,
    ROUND(AVG(pct_used), 2) AS avg_pct_used
FROM dba_database_sizes
WHERE sample_time >= SYSTIMESTAMP - 7
GROUP BY tablespace_name
ORDER BY growth_mb DESC;

CREATE OR REPLACE VIEW dba_v_blocking_sessions AS
SELECT 
    s1.sid AS blocked_sid,
    s1.username AS blocked_user,
    s1.program AS blocked_program,
    s1.event AS blocked_event,
    s2.sid AS blocker_sid,
    s2.username AS blocker_user,
    s2.program AS blocker_program,
    s2.event AS blocker_event,
    s1.seconds_in_wait
FROM v$session s1
JOIN v$session s2 ON s1.blocking_session = s2.sid
WHERE s1.blocking_session IS NOT NULL;

CREATE OR REPLACE VIEW dba_v_invalid_objects AS
SELECT 
    owner,
    object_type,
    object_name,
    status,
    TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI') AS last_modified
FROM dba_objects
WHERE status = 'INVALID'
  AND owner NOT IN ('SYS', 'SYSTEM', 'OUTLN')
ORDER BY owner, object_type, object_name;

CREATE OR REPLACE VIEW dba_v_index_bloat AS
SELECT 
    owner,
    index_name,
    table_name,
    blevel,
    leaf_blocks,
    clustering_factor,
    ROUND((leaf_blocks * 8192) / 1024 / 1024, 2) AS size_mb,
    CASE 
        WHEN clustering_factor > num_rows * 0.1 THEN 'HIGH'
        ELSE 'OK'
    END AS recommendation
FROM dba_indexes i
JOIN dba_tables t ON i.owner = t.owner AND i.table_name = t.table_name
WHERE i.owner NOT IN ('SYS', 'SYSTEM')
  AND i.index_type = 'NORMAL';

PROMPT Created 8 views for Oracle DBATools.
