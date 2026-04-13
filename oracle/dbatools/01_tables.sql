-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- Oracle DBATools Tables
-- Run as DBATOOLS user

-- Wait Statistics History
CREATE TABLE dba_wait_stats (
    sample_time TIMESTAMP,
    wait_class VARCHAR2(80),
    event_name VARCHAR2(100),
    wait_count NUMBER,
    time_waited_ms NUMBER,
    PRIMARY KEY (sample_time, event_name)
) COMPRESS FOR OLTP;

-- Session Snapshot History
CREATE TABLE dba_session_snapshot (
    sample_time TIMESTAMP,
    sid NUMBER,
    serial# NUMBER,
    username VARCHAR2(100),
    status VARCHAR2(20),
    program VARCHAR2(100),
    machine VARCHAR2(100),
    sql_id VARCHAR2(20),
    event VARCHAR2(100),
    seconds_in_wait NUMBER,
    PRIMARY KEY (sample_time, sid, serial#)
) COMPRESS FOR OLTP;

-- Database Size History
CREATE TABLE dba_database_sizes (
    sample_time TIMESTAMP,
    tablespace_name VARCHAR2(30),
    total_mb NUMBER,
    used_mb NUMBER,
    free_mb NUMBER,
    pct_used NUMBER,
    PRIMARY KEY (sample_time, tablespace_name)
) COMPRESS FOR OLTP;

-- Table Size History
CREATE TABLE dba_table_sizes (
    sample_time TIMESTAMP,
    owner VARCHAR2(100),
    table_name VARCHAR2(100),
    tablespace_name VARCHAR2(30),
    size_mb NUMBER,
    num_rows NUMBER,
    blocks NUMBER,
    PRIMARY KEY (sample_time, owner, table_name)
) COMPRESS FOR OLTP;

-- SQL Performance History
CREATE TABLE dba_sql_stats (
    sample_time TIMESTAMP,
    sql_id VARCHAR2(20),
    sql_text VARCHAR2(1000),
    executions NUMBER,
    elapsed_time_ns NUMBER,
    cpu_time_ns NUMBER,
    buffer_gets NUMBER,
    disk_reads NUMBER,
    PRIMARY KEY (sample_time, sql_id)
) COMPRESS FOR OLTP;

-- Backup History
CREATE TABLE dba_backup_history (
    backup_time TIMESTAMP,
    backup_type VARCHAR2(10),
    status VARCHAR2(20),
    input_bytes_mb NUMBER,
    output_bytes_mb NUMBER,
    duration_seconds NUMBER,
    PRIMARY KEY (backup_time, backup_type)
) COMPRESS FOR OLTP;

-- Error Log Capture
CREATE TABLE dba_error_log (
    log_time TIMESTAMP,
    ora_err_number NUMBER,
    ora_err_mesg VARCHAR2(4000),
    ora_err_line NUMBER,
    sql_text VARCHAR2(4000),
    PRIMARY KEY (log_time, ora_err_number, sql_text)
) COMPRESS FOR OLTP;

-- Index Usage Stats
CREATE TABLE dba_index_stats (
    sample_time TIMESTAMP,
    owner VARCHAR2(100),
    index_name VARCHAR2(100),
    table_name VARCHAR2(100),
    blevel NUMBER,
    leaf_blocks NUMBER,
    distinct_keys NUMBER,
    num_rows NUMBER,
    clustering_factor NUMBER,
    PRIMARY KEY (sample_time, owner, index_name)
) COMPRESS FOR OLTP;

-- Create indexes for performance
CREATE INDEX ix_wait_stats_time ON dba_wait_stats(sample_time);
CREATE INDEX ix_session_snap_time ON dba_session_snapshot(sample_time);
CREATE INDEX ix_db_sizes_time ON dba_database_sizes(sample_time);
CREATE INDEX ix_sql_stats_time ON dba_sql_stats(sample_time);
CREATE INDEX ix_sql_stats_sqlid ON dba_sql_stats(sql_id);

PROMPT Created 8 tables for Oracle DBATools.
