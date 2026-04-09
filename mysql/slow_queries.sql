-- ============================================================================
-- Script: slow_queries.sql
-- Purpose: Slow query log analysis
-- Usage:   Identify query optimization candidates
-- Notes:   Requires slow_query_log enabled and log_output=TABLE
-- ============================================================================

SELECT 
    start_time,
    user_host,
    query_time,
    lock_time,
    rows_sent,
    rows_examined,
    db,
    LEFT(sql_text, 200) AS sql_sample,
    last_insert_id,
    insert_id,
    server_id,
    sql_type
FROM mysql.slow_log
WHERE start_time >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY query_time DESC
LIMIT 50;
