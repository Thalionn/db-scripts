-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- Oracle DBATools Procedures
-- Run as DBATOOLS user

CREATE OR REPLACE PROCEDURE dba.capture_wait_stats AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_wait_stats (sample_time, wait_class, event_name, wait_count, time_waited_ms)
    SELECT 
        v_time,
        wait_class,
        event,
        wait_count,
        time_waited_ms
    FROM v$system_event
    WHERE wait_count > 0
      AND wait_class != 'Idle';
    
    COMMIT;
END dba.capture_wait_stats;
/

CREATE OR REPLACE PROCEDURE dba.capture_session_snapshot AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_session_snapshot (
        sample_time, sid, serial#, username, status, program, 
        machine, sql_id, event, seconds_in_wait
    )
    SELECT 
        v_time,
        sid,
        serial#,
        username,
        status,
        program,
        machine,
        sql_id,
        event,
        seconds_in_wait
    FROM v$session
    WHERE username IS NOT NULL;
    
    COMMIT;
END dba.capture_session_snapshot;
/

CREATE OR REPLACE PROCEDURE dba.capture_tablespace_sizes AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_database_sizes (
        sample_time, tablespace_name, total_mb, used_mb, free_mb, pct_used
    )
    SELECT 
        v_time,
        df.tablespace_name,
        SUM(df.bytes) / 1024 / 1024 AS total_mb,
        SUM(fs.bytes) / 1024 / 1024 AS used_mb,
        (SUM(df.bytes) - SUM(fs.bytes)) / 1024 / 1024 AS free_mb,
        (SUM(fs.bytes) * 100 / SUM(df.bytes)) AS pct_used
    FROM dba_data_files df
    JOIN dba_free_space fs ON df.tablespace_name = fs.tablespace_name
    GROUP BY df.tablespace_name;
    
    COMMIT;
END dba.capture_tablespace_sizes;
/

CREATE OR REPLACE PROCEDURE dba.capture_table_sizes AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_table_sizes (
        sample_time, owner, table_name, tablespace_name, size_mb, num_rows, blocks
    )
    SELECT 
        v_time,
        owner,
        table_name,
        tablespace_name,
        SUM(bytes) / 1024 / 1024 AS size_mb,
        SUM(num_rows) AS num_rows,
        SUM(blocks) AS blocks
    FROM dba_tables
    WHERE owner NOT IN ('SYS', 'SYSTEM')
    GROUP BY owner, table_name, tablespace_name;
    
    COMMIT;
END dba.capture_table_sizes;
/

CREATE OR REPLACE PROCEDURE dba.capture_sql_stats AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_sql_stats (
        sample_time, sql_id, sql_text, executions, elapsed_time_ns, 
        cpu_time_ns, buffer_gets, disk_reads
    )
    SELECT 
        v_time,
        sql_id,
        SUBSTR(sql_text, 1, 1000),
        executions,
        elapsed_time_ns,
        cpu_time_ns,
        buffer_gets,
        disk_reads
    FROM v$sqlarea
    WHERE executions > 10
      AND substr(sql_text, 1, 10) != 'DECLARE ';
    
    COMMIT;
END dba.capture_sql_stats;
/

CREATE OR REPLACE PROCEDURE dba.capture_index_stats AS
    v_time TIMESTAMP := SYSTIMESTAMP;
BEGIN
    INSERT INTO dba_index_stats (
        sample_time, owner, index_name, table_name, blevel, leaf_blocks,
        distinct_keys, num_rows, clustering_factor
    )
    SELECT 
        v_time,
        owner,
        index_name,
        table_name,
        blevel,
        leaf_blocks,
        distinct_keys,
        num_rows,
        clustering_factor
    FROM dba_indexes
    WHERE owner NOT IN ('SYS', 'SYSTEM');
    
    COMMIT;
END dba.capture_index_stats;
/

CREATE OR REPLACE PROCEDURE dba.purge_old_data(p_days NUMBER := 30) AS
BEGIN
    DELETE FROM dba_wait_stats WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_session_snapshot WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_database_sizes WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_table_sizes WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_sql_stats WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_index_stats WHERE sample_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_backup_history WHERE backup_time < SYSTIMESTAMP - p_days;
    DELETE FROM dba_error_log WHERE log_time < SYSTIMESTAMP - p_days;
    COMMIT;
END dba.purge_old_data;
/

PROMPT Created 7 procedures for Oracle DBATools.
