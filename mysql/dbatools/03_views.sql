-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- MySQL DBATools Views
USE dbatools;

CREATE OR REPLACE VIEW v_top_queries AS
SELECT 
    schema_name,
    query_text,
    exec_count,
    avg_time,
    total_time,
    rows_sent,
    rows_examined,
    ROUND(avg_time * exec_count / 1000, 2) AS total_time_sec
FROM query_stats
WHERE sample_time >= NOW() - INTERVAL 1 HOUR
ORDER BY total_time DESC
LIMIT 20;

CREATE OR REPLACE VIEW v_table_sizes AS
SELECT 
    table_schema,
    table_name,
    engine,
    data_length_mb,
    index_length_mb,
    total_size_mb,
    table_rows,
    sample_time
FROM table_sizes
WHERE sample_time >= NOW() - INTERVAL 1 DAY
ORDER BY total_size_mb DESC;

CREATE OR REPLACE VIEW v_large_tables AS
SELECT 
    table_schema,
    table_name,
    total_size_mb,
    table_rows
FROM table_sizes
WHERE sample_time >= NOW() - INTERVAL 1 DAY
  AND total_size_mb > 1000
ORDER BY total_size_mb DESC;

CREATE OR REPLACE VIEW v_connection_summary AS
SELECT 
    sample_time,
    SUM(CASE WHEN command_type = 'Query' THEN count ELSE 0 END) AS queries,
    SUM(CASE WHEN command_type = 'Sleep' THEN count ELSE 0 END) AS sleeps,
    SUM(CASE WHEN command_type = 'Connect' THEN count ELSE 0 END) AS connects,
    SUM(count) AS total
FROM connection_stats
WHERE sample_time >= NOW() - INTERVAL 1 HOUR
GROUP BY sample_time;

CREATE OR REPLACE VIEW v_slow_queries AS
SELECT 
    start_time,
    user_host,
    query_time,
    rows_sent,
    rows_examined,
    sql_text
FROM slow_queries
WHERE sample_time >= NOW() - INTERVAL 24 HOUR
ORDER BY query_time DESC;

CREATE OR REPLACE VIEW v_replication_lag AS
SELECT 
    sample_time,
    master_host,
    seconds_behind_master,
    master_log_file,
    read_master_log_pos,
    exec_master_log_pos
FROM replication_status
WHERE sample_time >= NOW() - INTERVAL 1 HOUR
ORDER BY sample_time DESC;

CREATE OR REPLACE VIEW v_innodb_buffer_pool AS
SELECT 
    variable_value / 1024 / 1024 AS buffer_pool_mb
FROM innodb_stats
WHERE variable_name = 'Innodb_buffer_pool_bytes_data';

CREATE OR REPLACE VIEW v_unused_indexes AS
SELECT 
    s.table_schema,
    s.table_name,
    s.index_name,
    s.cardinality,
    t.table_rows,
    CASE 
        WHEN s.cardinality = 0 OR s.cardinality IS NULL THEN 'UNUSED'
        WHEN t.table_rows > 0 AND s.cardinality / t.table_rows < 0.01 THEN 'LOW SELECTIVITY'
        ELSE 'OK'
    END AS status
FROM index_stats s
JOIN (
    SELECT table_schema, table_name, MAX(table_rows) AS table_rows
    FROM table_sizes
    WHERE sample_time >= NOW() - INTERVAL 1 DAY
    GROUP BY table_schema, table_name
) t ON s.table_schema = t.table_schema AND s.table_name = t.table_name
WHERE s.sample_time >= NOW() - INTERVAL 1 DAY
  AND s.non_unique = 1
ORDER BY s.cardinality ASC;

CREATE OR REPLACE VIEW v_database_growth AS
SELECT 
    table_schema,
    MIN(total_size_mb) AS min_size_mb,
    MAX(total_size_mb) AS max_size_mb,
    MAX(total_size_mb) - MIN(total_size_mb) AS growth_mb,
    AVG(total_size_mb) AS avg_size_mb
FROM table_sizes
WHERE sample_time >= NOW() - INTERVAL 7 DAY
GROUP BY table_schema
ORDER BY growth_mb DESC;

PROMPT Created 9 views for MySQL DBATools.
