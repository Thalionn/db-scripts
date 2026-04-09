-- ============================================================================
-- Script: innodb_status.sql
-- Purpose: InnoDB engine metrics snapshot
-- Usage:   Check for deadlock traces, lock waits, buffer pool status
-- Notes:   Run SHOW ENGINE INNODB STATUS for full output
-- ============================================================================

SELECT 
    VARIABLE_NAME,
    VARIABLE_VALUE,
    CASE 
        WHEN VARIABLE_NAME LIKE '%Buffer_pool_size%' 
        THEN ROUND(VARIABLE_VALUE / 1024 / 1024 / 1024, 2)
        WHEN VARIABLE_NAME LIKE '%Innodb_page_size%'
        THEN VARIABLE_VALUE
        ELSE VARIABLE_VALUE
    END AS parsed_value
FROM information_schema.GLOBAL_STATUS
WHERE VARIABLE_NAME IN (
    'Innodb_buffer_pool_pages_total',
    'Innodb_buffer_pool_pages_free',
    'Innodb_buffer_pool_pages_dirty',
    'Innodb_buffer_pool_read_requests',
    'Innodb_buffer_pool_reads',
    'Innodb_row_lock_waits',
    'Innodb_row_lock_time',
    'Innodb_deadlocks',
    'Innodb_log_waits',
    'Threads_connected',
    'Threads_running',
    'Aborted_connects',
    'Connections'
)
ORDER BY VARIABLE_NAME;
