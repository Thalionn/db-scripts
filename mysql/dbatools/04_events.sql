-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- MySQL DBATools Event Scheduler Jobs
USE dbatools;

-- Enable the event scheduler
SET GLOBAL event_scheduler = ON;

-- Event: Capture query stats every 15 minutes
CREATE EVENT IF NOT EXISTS evt_capture_query_stats
ON SCHEDULE EVERY 15 MINUTE
DO
CALL capture_query_stats();

-- Event: Capture connection stats every 5 minutes
CREATE EVENT IF NOT EXISTS evt_capture_connection_stats
ON SCHEDULE EVERY 5 MINUTE
DO
CALL capture_connection_stats();

-- Event: Capture table sizes hourly
CREATE EVENT IF NOT EXISTS evt_capture_table_sizes
ON SCHEDULE EVERY 1 HOUR
DO
CALL capture_table_sizes();

-- Event: Capture index stats daily at 3 AM
CREATE EVENT IF NOT EXISTS evt_capture_index_stats
ON SCHEDULE EVERY 1 DAY AT '03:00:00'
DO
CALL capture_index_stats();

-- Event: Capture replication status every 5 minutes
CREATE EVENT IF NOT EXISTS evt_capture_replication_status
ON SCHEDULE EVERY 5 MINUTE
DO
CALL capture_replication_status();

-- Event: Capture InnoDB stats every 15 minutes
CREATE EVENT IF NOT EXISTS evt_capture_innodb_stats
ON SCHEDULE EVERY 15 MINUTE
DO
CALL capture_innodb_stats();

-- Event: Purge old data daily at 2 AM
CREATE EVENT IF NOT EXISTS evt_purge_old_data
ON SCHEDULE EVERY 1 DAY AT '02:00:00'
DO
CALL purge_old_data(30);

-- Event: Capture slow queries every hour
CREATE EVENT IF NOT EXISTS evt_capture_slow_queries
ON SCHEDULE EVERY 1 HOUR
DO
CALL capture_slow_queries(24);

PROMPT Created 8 events for MySQL DBATools.
PROMPT Use SELECT * FROM information_schema.EVENTS to view event status.
