-- ============================================================================
-- Script: replication_status.sql
-- Purpose: Master/slave replication health
-- Usage:   Verify replication is running without lag
-- Notes:   Run on master for overview, slave for detailed status
-- ============================================================================

SELECT 
    @@server_id AS this_server_id,
    @@hostname AS hostname,
    service_state AS io_running,
    slave_sql_running_state,
    Seconds_Behind_Master AS lag_seconds,
    LAST_ERROR_MESSAGE AS last_error,
    LAST_ERROR_TIMESTAMP,
    COUNT_READ AS events_read,
    COUNT_ERROR AS relay_errors
FROM mysql.slave_master_info m
JOIN performance_schema.replication_connection_status s 
    ON s.channel_name = m.channel_name
JOIN performance_schema.replication_applier_status a 
    ON a.channel_name = m.channel_name;
