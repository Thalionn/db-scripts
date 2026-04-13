-- ============================================================================
-- Script: quick_health_check.sql
-- Purpose: Consolidated MySQL health check
-- Usage:   mysql < quick_health_check.sql
-- Notes:   Run with root or admin user
-- ============================================================================

SELECT '============================================================' AS '';
SELECT 'MySQL Quick Health Check' AS '';
SELECT CONCAT('Server: ', @@version) AS '';
SELECT CONCAT('Database: ', DATABASE()) AS '';
SELECT CONCAT('Time: ', NOW()) AS '';
SELECT '============================================================' AS '';

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '1. SERVER STATUS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@version AS Version,
    @@version_comment AS Comment,
    @@datadir AS DataDir,
    @@max_connections AS MaxConnections,
    @@character_set_server AS Charset,
    @@collation_server AS Collation;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '2. CONNECTION STATUS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    user,
    host,
    command,
    time AS sec_in_state,
    state,
    LEFT(info, 100) AS current_query
FROM information_schema.processlist
WHERE id != CONNECTION_ID()
ORDER BY time DESC
LIMIT 30;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '3. SLOW QUERIES (Last 24h)' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    start_time,
    query_time,
    rows_sent,
    rows_examined,
    db,
    LEFT(sql_text, 200) AS sql_text
FROM mysql.slow_log
WHERE start_time > DATE_SUB(NOW(), INTERVAL 24 HOUR)
ORDER BY query_time DESC
LIMIT 20;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '4. TABLE STATISTICS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    TABLE_TYPE,
    ENGINE,
    ROUND(data_length / 1024 / 1024, 2) AS data_size_mb,
    ROUND(index_length / 1024 / 1024, 2) AS index_size_mb,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS total_size_mb,
    table_rows,
    AUTO_INCREMENT AS next_auto_inc,
    update_time
FROM information_schema.tables
WHERE table_schema NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
  AND table_type = 'BASE TABLE'
ORDER BY (data_length + index_length) DESC
LIMIT 20;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '5. INDEX USAGE' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    OBJECT_SCHEMA,
    OBJECT_NAME,
    INDEX_NAME,
    NON_UNIQUE,
    SEQ_IN_INDEX,
    COLUMN_NAME,
    CARDINALITY
FROM information_schema.STATISTICS
WHERE OBJECT_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
ORDER BY OBJECT_SCHEMA, OBJECT_NAME, SEQ_IN_INDEX
LIMIT 50;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '6. INNODB STATUS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME IN (
    'Innodb_buffer_pool_bytes_data',
    'Innodb_buffer_pool_bytes_dirty',
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_dirty',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_current_waits',
    'Innodb_tables_in_use',
    'Innodb_tables_lockeds'
);

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '7. REPLICATION STATUS' AS '';
SELECT '------------------------------------------------------------' AS '';

SHOW SLAVE STATUS\G

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '8. TABLE LOCKS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    Lock_type,
    Lock_mode,
    Lock_status,
    COUNT(*) AS wait_count
FROM information_schema.LOCKS
GROUP BY TABLE_SCHEMA, TABLE_NAME, Lock_type, Lock_mode, Lock_status
ORDER BY wait_count DESC
LIMIT 20;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '9. DATABASE SIZES' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    TABLE_SCHEMA AS DatabaseName,
    ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS SizeMB,
    ROUND(SUM(data_length) / 1024 / 1024, 2) AS DataMB,
    ROUND(SUM(index_length) / 1024 / 1024, 2) AS IndexMB,
    COUNT(*) AS TableCount
FROM information_schema.tables
WHERE TABLE_SCHEMA NOT IN ('information_schema', 'mysql', 'performance_schema', 'sys')
  AND table_type = 'BASE TABLE'
GROUP BY TABLE_SCHEMA
ORDER BY SizeMB DESC;

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT '10. RECENT ERRORS' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    logged AS Time,
    prio AS Priority,
    error_code AS Code,
    LEFT(argument, 200) AS Message
FROM mysql.error_log
WHERE logged > DATE_SUB(NOW(), INTERVAL 24 HOUR)
  AND prio IN ('Error', 'Warning')
ORDER BY logged DESC
LIMIT 20;

SELECT '' AS '';

SELECT '============================================================' AS '';
SELECT 'Health Check Complete' AS '';
SELECT '============================================================' AS '';
