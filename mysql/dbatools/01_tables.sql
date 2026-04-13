-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- MySQL DBATools Tables
USE dbatools;

-- Query Performance History
CREATE TABLE IF NOT EXISTS query_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    schema_name VARCHAR(64),
    query_text VARCHAR(1000),
    exec_count BIGINT,
    total_time BIGINT,
    avg_time DECIMAL(10,3),
    rows_sent BIGINT,
    rows_examined BIGINT,
    INDEX idx_sample (sample_time),
    INDEX idx_schema (schema_name)
) ENGINE=InnoDB;

-- Connection History
CREATE TABLE IF NOT EXISTS connection_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    user_host VARCHAR(100),
    command_type VARCHAR(50),
    count INT,
    INDEX idx_sample (sample_time)
) ENGINE=InnoDB;

-- Table Size History
CREATE TABLE IF NOT EXISTS table_sizes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    table_schema VARCHAR(64),
    table_name VARCHAR(64),
    engine VARCHAR(20),
    data_length BIGINT,
    index_length BIGINT,
    data_length_mb DECIMAL(10,2),
    index_length_mb DECIMAL(10,2),
    total_size_mb DECIMAL(10,2),
    table_rows BIGINT,
    INDEX idx_sample (sample_time),
    INDEX idx_table (table_schema, table_name)
) ENGINE=InnoDB;

-- Index Statistics
CREATE TABLE IF NOT EXISTS index_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    table_schema VARCHAR(64),
    table_name VARCHAR(64),
    index_name VARCHAR(64),
    non_unique INT,
    seq_in_index INT,
    column_name VARCHAR(64),
    cardinality BIGINT,
    INDEX idx_sample (sample_time),
    INDEX idx_table (table_schema, table_name)
) ENGINE=InnoDB;

-- Slow Query Log
CREATE TABLE IF NOT EXISTS slow_queries (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    start_time DATETIME,
    user_host VARCHAR(100),
    query_time DECIMAL(10,6),
    lock_time DECIMAL(10,6),
    rows_sent INT,
    rows_examined BIGINT,
    sql_text VARCHAR(2000),
    INDEX idx_sample (sample_time),
    INDEX idx_time (start_time)
) ENGINE=InnoDB;

-- Replication Status
CREATE TABLE IF NOT EXISTS replication_status (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    master_host VARCHAR(100),
    master_port INT,
    master_log_file VARCHAR(100),
    read_master_log_pos BIGINT,
    relay_master_log_file VARCHAR(100),
    exec_master_log_pos BIGINT,
    seconds_behind_master INT,
    INDEX idx_sample (sample_time)
) ENGINE=InnoDB;

-- InnoDB Status
CREATE TABLE IF NOT EXISTS innodb_stats (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sample_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    variable_name VARCHAR(100),
    variable_value VARCHAR(255),
    INDEX idx_sample (sample_time)
) ENGINE=InnoDB;

-- Error Log
CREATE TABLE IF NOT EXISTS error_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    logged DATETIME,
    priority VARCHAR(20),
    error_code VARCHAR(20),
    message VARCHAR(1000),
    INDEX idx_logged (logged)
) ENGINE=InnoDB;

PROMPT Created 8 tables for MySQL DBATools.
