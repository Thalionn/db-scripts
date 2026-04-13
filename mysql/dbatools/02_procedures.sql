-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- MySQL DBATools Procedures
USE dbatools;

DELIMITER //

CREATE PROCEDURE capture_query_stats()
BEGIN
    INSERT INTO query_stats (schema_name, query_text, exec_count, total_time, avg_time, rows_sent, rows_examined)
    SELECT 
        SCHEMA_NAME,
        SUBSTRING DIGEST_TEXT,
        COUNT_STAR,
        SUM_TIMER_WAIT,
        AVG_TIMER_WAIT / 1000000,
        SUM_ROWS_SENT,
        SUM_ROWS_EXAMINED
    FROM performance_schema.events_statements_summary_by_digest
    WHERE SCHEMA_NAME IS NOT NULL
      AND COUNT_STAR > 10
    ON DUPLICATE KEY UPDATE exec_count = VALUES(exec_count);
END//

CREATE PROCEDURE capture_connection_stats()
BEGIN
    INSERT INTO connection_stats (user_host, command_type, count)
    SELECT 
        USER,
        COMMAND,
        COUNT(*)
    FROM information_schema.PROCESSLIST
    GROUP BY USER, COMMAND;
END//

CREATE PROCEDURE capture_table_sizes()
BEGIN
    INSERT INTO table_sizes (table_schema, table_name, engine, data_length, index_length, data_length_mb, index_length_mb, total_size_mb, table_rows)
    SELECT 
        TABLE_SCHEMA,
        TABLE_NAME,
        ENGINE,
        data_length,
        index_length,
        ROUND(data_length / 1024 / 1024, 2),
        ROUND(index_length / 1024 / 1024, 2),
        ROUND((data_length + index_length) / 1024 / 1024, 2),
        TABLE_ROWS
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
      AND TABLE_TYPE = 'BASE TABLE';
END//

CREATE PROCEDURE capture_index_stats()
BEGIN
    INSERT INTO index_stats (table_schema, table_name, index_name, non_unique, seq_in_index, column_name, cardinality)
    SELECT 
        TABLE_SCHEMA,
        TABLE_NAME,
        INDEX_NAME,
        NON_UNIQUE,
        SEQ_IN_INDEX,
        COLUMN_NAME,
        CARDINALITY
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys');
END//

CREATE PROCEDURE capture_slow_queries(IN hours_back INT)
BEGIN
    INSERT INTO slow_queries (start_time, user_host, query_time, lock_time, rows_sent, rows_examined, sql_text)
    SELECT 
        START_TIME,
        USER,
        QUERY_TIME,
        LOCK_TIME,
        ROWS_SENT,
        ROWS_EXAMINED,
        SQL_TEXT
    FROM mysql.slow_log
    WHERE START_TIME > DATE_SUB(NOW(), INTERVAL hours_back HOUR);
END//

CREATE PROCEDURE capture_replication_status()
BEGIN
    INSERT INTO replication_status (master_host, master_port, master_log_file, read_master_log_pos, relay_master_log_file, exec_master_log_pos, seconds_behind_master)
    SELECT 
        MASTER_HOST,
        MASTER_PORT,
        MASTER_LOG_NAME,
        READ_MASTER_LOG_POS,
        RELAY_LOG_NAME,
        EXEC_MASTER_LOG_POS,
        SECONDS_BEHIND_MASTER
    FROM mysql.slave_master_info;
END//

CREATE PROCEDURE capture_innodb_stats()
BEGIN
    INSERT INTO innodb_stats (variable_name, variable_value)
    SELECT 
        VARIABLE_NAME,
        VARIABLE_VALUE
    FROM information_schema.GLOBAL_STATUS
    WHERE VARIABLE_NAME LIKE 'Innodb%';
END//

CREATE PROCEDURE purge_old_data(IN days_to_keep INT)
BEGIN
    DELETE FROM query_stats WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM connection_stats WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM table_sizes WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM index_stats WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM slow_queries WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM replication_status WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
    DELETE FROM innodb_stats WHERE sample_time < DATE_SUB(NOW(), INTERVAL days_to_keep DAY);
END//

DELIMITER ;

PROMPT Created 8 procedures for MySQL DBATools.
