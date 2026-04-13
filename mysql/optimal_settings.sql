-- ============================================================================
-- Script: optimal_settings.sql
-- Purpose: Apply MySQL/MariaDB best practice settings
-- Usage:   mysql < optimal_settings.sql
-- Notes:   Review before applying in production
-- ============================================================================

SELECT '============================================================' AS '';
SELECT 'MySQL Optimal Configuration Script' AS '';
SELECT 'Based on community best practices' AS '';
SELECT '============================================================' AS '';

SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 1: InnoDB Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@innodb_buffer_pool_size AS buffer_pool_size,
    @@innodb_log_file_size AS log_file_size,
    @@innodb_flush_log_at_trx_commit AS flush_log_at_trx_commit,
    @@innodb_flush_method AS flush_method,
    @@innodb_file_per_table AS file_per_table;

SELECT '' AS '';
SELECT 'Recommended settings:' AS '';
SELECT 'SET GLOBAL innodb_buffer_pool_size = X;  -- 70-80% of available RAM' AS '';
SELECT 'SET GLOBAL innodb_log_file_size = X;  -- 25% of buffer pool' AS '';
SELECT 'SET GLOBAL innodb_flush_log_at_trx_commit = 2;  -- 1 for ACID, 2 for perf' AS '';
SELECT 'SET GLOBAL innodb_file_per_table = 1;' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 2: Connection Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@max_connections AS max_connections,
    @@max_connect_errors AS max_connect_errors,
    @@wait_timeout AS wait_timeout,
    @@interactive_timeout AS interactive_timeout;

SELECT '' AS '';
SELECT 'Recommended:' AS '';
SELECT 'SET GLOBAL max_connections = 300;' AS '';
SELECT 'SET GLOBAL max_connect_errors = 100000;' AS '';
SELECT 'SET GLOBAL wait_timeout = 600;  -- 10 min' AS '';
SELECT 'SET GLOBAL interactive_timeout = 600;' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 3: Query Cache (MySQL 5.7 and below)' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@query_cache_type AS query_cache_type,
    @@query_cache_size AS query_cache_size,
    @@query_cache_limit AS query_cache_limit;

SELECT '' AS '';
SELECT 'Note: Query cache deprecated in 8.0+ (removed in MySQL 8.0.20)' AS '';
SELECT 'Use: SET GLOBAL query_cache_type = 0; to disable' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 4: Temporary Table Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@tmp_table_size AS tmp_table_size,
    @@max_heap_table_size AS max_heap_table_size,
    @@tmpdir AS tmpdir;

SELECT '' AS '';
SELECT 'Recommended:' AS '';
SELECT 'SET GLOBAL tmp_table_size = 256M;' AS '';
SELECT 'SET GLOBAL max_heap_table_size = 256M;' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 5: Logging Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@slow_query_log AS slow_query_log,
    @@slow_query_log_file AS slow_query_log_file,
    @@long_query_time AS long_query_time,
    @@log_queries_not_using_indexes AS log_queries_not_using_indexes,
    @@general_log AS general_log;

SELECT '' AS '';
SELECT 'Recommended:' AS '';
SELECT 'SET GLOBAL slow_query_log = 1;' AS '';
SELECT 'SET GLOBAL long_query_time = 2;  -- log queries > 2s' AS '';
SELECT 'SET GLOBAL log_queries_not_using_indexes = 1;' AS '';
SELECT 'SET GLOBAL slow_query_log_file = ''/var/lib/mysql/slow.log'';' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 6: Binary Log Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@log_bin AS log_bin,
    @@binlog_format AS binlog_format,
    @@expire_logs_days AS expire_logs_days,
    @@max_binlog_size AS max_binlog_size,
    @@sync_binlog AS sync_binlog;

SELECT '' AS '';
SELECT 'Recommended for replication:' AS '';
SELECT 'SET GLOBAL binlog_format = ''ROW'';' AS '';
SELECT 'SET GLOBAL expire_logs_days = 7;' AS '';
SELECT 'SET GLOBAL max_binlog_size = 1G;' AS '';
SELECT 'SET GLOBAL sync_binlog = 1;  -- for durability (0 for perf)' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 7: Character Set Settings' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@character_set_server AS character_set_server,
    @@collation_server AS collation_server,
    @@character_set_filesystem AS character_set_filesystem;

SELECT '' AS '';
SELECT 'Recommended:' AS '';
SELECT "SET GLOBAL character_set_server = 'utf8mb4';" AS '';
SELECT "SET GLOBAL collation_server = 'utf8mb4_unicode_ci';" AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 8: InnoDB Performance' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@innodb_io_capacity AS io_capacity,
    @@innodb_io_capacity_max AS io_capacity_max,
    @@innodb_read_io_threads AS read_io_threads,
    @@innodb_write_io_threads AS write_io_threads,
    @@innodb_thread_concurrency AS thread_concurrency;

SELECT '' AS '';
SELECT 'Recommended for SSDs:' AS '';
SELECT 'SET GLOBAL innodb_io_capacity = 2000;' AS '';
SELECT 'SET GLOBAL innodb_io_capacity_max = 4000;' AS '';
SELECT 'SET GLOBAL innodb_read_io_threads = 8;' AS '';
SELECT 'SET GLOBAL innodb_write_io_threads = 8;' AS '';
SELECT 'SET GLOBAL innodb_thread_concurrency = 0;  -- unlimited' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 9: Table Open Cache' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@table_open_cache AS table_open_cache,
    @@table_definition_cache AS table_definition_cache,
    @@table_definition_cache AS max_connections;

SELECT '' AS '';
SELECT 'Recommended:' AS '';
SELECT 'SET GLOBAL table_open_cache = 4000;' AS '';
SELECT 'SET GLOBAL table_definition_cache = 2000;' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 10: Performance Schema' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 
    @@performance_schema AS performance_schema,
    @@performance_schema_instrument AS instrument;

SELECT '' AS '';
SELECT 'Enable for diagnostics:' AS '';
SELECT 'SET GLOBAL performance_schema = ON;' AS '';
SELECT 'SET GLOBAL performance_schema_instrument = ''%=ON'';' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 11: MariaDB Specific' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT @@version LIKE '%MariaDB%' AS is_mariadb;

SELECT '' AS '';
SELECT 'MariaDB optimizations:' AS '';
SELECT "SET GLOBAL optimizer_switch = 'index_condition_pushdown=on,switch_engine=1';" AS '';
SELECT 'SET GLOBAL join_buffer_size = 256M;' AS '';
SELECT '' AS '';

SELECT '------------------------------------------------------------' AS '';
SELECT 'SECTION 12: Current Status Summary' AS '';
SELECT '------------------------------------------------------------' AS '';

SELECT 'Uptime:' AS '', @@uptime AS '';
SELECT 'Version:' AS '', @@version AS '';
SELECT 'Data size:' AS '', (SELECT SUM(data_length + index_length) FROM information_schema.tables WHERE table_schema = DATABASE()) / 1024 / 1024 AS 'MB';
SELECT 'Buffer pool size:' AS '', @@innodb_buffer_pool_size / 1024 / 1024 AS 'MB';

SELECT '' AS '';
SELECT '============================================================' AS '';
SELECT 'REVIEW MANUALLY BEFORE APPLYING:' AS '';
SELECT '============================================================' AS '';
SELECT '' AS '';
SELECT '1. my.cnf settings to review:' AS '';
SELECT '   - innodb_buffer_pool_size (70-80% of RAM)' AS '';
SELECT '   - max_connections' AS '';
SELECT '   - log settings' AS '';
SELECT '' AS '';
SELECT '2. For replication:' AS '';
SELECT '   - server-id (must be unique)' AS '';
SELECT '   - binlog settings' AS '';
SELECT '   - relay log settings' AS '';
SELECT '' AS '';
SELECT '3. Security:' AS '';
SELECT '   - SET GLOBAL sql_mode = ''STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION'';' AS '';
SELECT '   - Remove test database' AS '';
SELECT '   - Secure root password' AS '';
SELECT '' AS '';
SELECT '4. Backup strategy' AS '';
SELECT '5. Monitoring setup' AS '';
SELECT '' AS '';
SELECT '============================================================' AS '';
SELECT 'Configuration script complete' AS '';
SELECT '============================================================' AS '';
