-- ============================================================================
-- Script: quick_health_check.sql
-- Purpose: Consolidated Oracle health check
-- Usage:   @quick_health_check.sql
-- Notes:   Run as DBA with SELECT_CATALOG_ROLE
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 5000
COLUMN status FORMAT A15
COLUMN name FORMAT A30
COLUMN username FORMAT A20
COLUMN program FORMAT A30
COLUMN module FORMAT A30

PROMPT ============================================================
PROMPT ORACLE QUICK HEALTH CHECK
PROMPT ============================================================
PROMPT Server: &HOST
PROMPT Database: &DBNAME
PROMPT Time: &SYSDATE
PROMPT ============================================================

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 1. DATABASE STATUS
PROMPT ------------------------------------------------------------

SELECT 
    name,
    open_mode,
    database_role,
    protection_mode,
    protection_level,
    switchover_status,
    TO_CHAR(created, 'YYYY-MM-DD') AS created
FROM v$database;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 2. TABLESPACE USAGE (Warning > 80%, Critical > 90%)
PROMPT ------------------------------------------------------------

SELECT 
    tablespace_name,
    status,
    ROUND(used_space / 1024 / 1024, 2) AS used_gb,
    ROUND(total_space / 1024 / 1024, 2) AS total_gb,
    ROUND((total_space - used_space) / 1024 / 1024, 2) AS free_gb,
    ROUND(used_space * 100.0 / total_space, 1) AS pct_used,
    CASE 
        WHEN used_space * 100.0 / total_space > 90 THEN 'CRITICAL'
        WHEN used_space * 100.0 / total_space > 80 THEN 'WARNING'
        ELSE 'OK'
    END AS status
FROM (
    SELECT df.tablespace_name,
           df.status,
           SUM(df.bytes) / 1024 / 1024 AS used_space,
           SUM(df.maxbytes) / 1024 / 1024 AS total_space
    FROM dba_data_files df
    GROUP BY df.tablespace_name, df.status
)
ORDER BY pct_used DESC;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 3. SESSION STATUS
PROMPT ------------------------------------------------------------

SELECT 
    status,
    COUNT(*) AS session_count,
    SUM(CASE WHEN type = 'USER' THEN 1 ELSE 0 END) AS user_sessions,
    SUM(CASE WHEN type = 'BACKGROUND' THEN 1 ELSE 0 END) AS bg_sessions
FROM v$session
GROUP BY status;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 4. TOP ACTIVE SESSIONS
PROMPT ------------------------------------------------------------

SELECT 
    s.username,
    s.osuser,
    s.program,
    s.module,
    s.status,
    s.wait_class,
    s.seconds_in_wait,
    s.sql_id,
    SUBSTR(sa.sql_text, 1, 100) AS sql_text
FROM v$session s
LEFT JOIN v$sqlarea sa ON s.sql_id = sa.sql_id
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY s.seconds_in_wait DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 5. TOP WAIT EVENTS
PROMPT ------------------------------------------------------------

SELECT 
    wait_class,
    event,
    time_waited,
    wait_count,
    ROUND(time_waited / 1000, 2) AS time_sec,
    ROUND(time_waited * 100 / SUM(time_waited) OVER(), 2) AS pct
FROM v$system_event
WHERE wait_class != 'Idle'
ORDER BY time_waited DESC
FETCH FIRST 15 ROWS ONLY;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 6. CURRENT BLOCKING SESSIONS
PROMPT ------------------------------------------------------------

SELECT 
    blocking_session AS blocker_sid,
    sid AS blocked_sid,
    seconds_in_wait AS wait_sec,
    wait_class,
    resource_1 AS resource_type,
    resource_2 AS id1,
    resource_3 AS id2,
    SQL_ID,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$session w
LEFT JOIN v$sqlarea sa ON w.sql_id = sa.sql_id
WHERE blocking_session IS NOT NULL
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 7. INVALID OBJECTS
PROMPT ------------------------------------------------------------

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

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 8. REDO LOG STATUS
PROMPT ------------------------------------------------------------

SELECT 
    group#,
    thread#,
    sequence#,
    bytes / 1024 / 1024 AS size_mb,
    members,
    status,
    first_change#,
    first_time
FROM v$log
ORDER BY group#;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 9. ARCHIVE LOG STATUS (Last 24 Hours)
PROMPT ------------------------------------------------------------

SELECT 
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hour,
    COUNT(*) AS archivelogs,
    SUM(blocks * block_size) / 1024 / 1024 AS size_mb
FROM v$archived_log
WHERE first_time > SYSDATE - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hour DESC;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 10. RMAN BACKUP STATUS (Last 7 Days)
PROMPT ------------------------------------------------------------

SELECT 
    ROUND(SUM(backup_size / 1024 / 1024 / 1024), 2) AS total_backup_gb,
    MAX(backup_time) AS last_backup,
    ROUND(AVG(backup_size / 1024 / 1024 / 1024), 2) AS avg_backup_gb,
    SUM(CASE WHEN backup_type = 'D' THEN 1 ELSE 0 END) AS full_backups,
    SUM(CASE WHEN backup_type = 'I' THEN 1 ELSE 0 END) AS incr_backups
FROM (
    SELECT 
        b.backup_type,
        b.backup_size,
        b.completion_time AS backup_time
    FROM v$backup_set b
    WHERE b.completion_time > SYSDATE - 7
);

PROMPT
PROMPT ------------------------------------------------------------
PROMPT 11. TOP SQL BY BUFFER GETS
PROMPT ------------------------------------------------------------

SELECT 
    substr(sql_text, 1, 100) AS sql_text,
    executions,
    buffer_gets,
    disk_reads,
    ROUND(buffer_gets / executions, 0) AS gets_per_exec,
    ROUND(disk_reads / executions, 0) AS reads_per_exec,
    sharable_mem,
    sql_id
FROM v$sqlarea
WHERE executions > 10
ORDER BY buffer_gets DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT HEALTH CHECK COMPLETE
PROMPT ============================================================

SET PAGESIZE 100
