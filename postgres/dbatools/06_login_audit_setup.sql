-- ============================================================================
-- Script: 06_login_audit_setup.sql
-- Purpose: Configure PostgreSQL for login auditing
-- Usage:   Run after 05_pgagent_jobs.sql
-- Notes:   PostgreSQL doesn't have server-level triggers like SQL Server.
--          This script shows how to configure login logging.
-- ============================================================================

-- Option 1: Use pg_log (PostgreSQL error log)
-- Add to postgresql.conf:
--
-- log_connections = on
-- log_disconnections = on
-- log_hostname = on
-- log_duration = off
-- log_line_prefix = '%m [%p] %q%u@%d '
--
-- Then parse the log file with this query:

CREATE OR REPLACE FUNCTION dba.parse_connection_logs(
    p_log_file TEXT DEFAULT 'postgresql.log',
    p_days_back INTEGER DEFAULT 1
)
RETURNS TABLE(
    log_time TIMESTAMP,
    username VARCHAR(128),
    database_name VARCHAR(128),
    client_addr INET,
    event_type VARCHAR(20),
    process_id BIGINT
) AS $$
BEGIN
    -- Note: This requires read access to the PostgreSQL log directory
    -- Adjust the path for your environment
    RAISE WARNING 'This function requires PostgreSQL log file access.';
    RAISE WARNING 'Configure log_directory in postgresql.conf and ensure read permissions.';
    
    RETURN;
END;
$$ LANGUAGE plpgsql;

-- Option 2: Create a connection tracking view
-- This requires superuser to query pg_stat_activity fully

CREATE OR REPLACE VIEW dba.v_current_connections_detail AS
SELECT 
    pid,
    usename AS username,
    application_name,
    client_addr,
    client_hostname,
    backend_start,
    state,
    query_start,
    state_change,
    wait_event_type,
    wait_event,
    LEFT(query, 200) AS current_query,
    CASE 
        WHEN state = 'active' AND query_start < NOW() - INTERVAL '5 minutes' THEN 'Long Running'
        WHEN state = 'idle in transaction' AND state_change < NOW() - INTERVAL '5 minutes' THEN 'Idle in Transaction'
        WHEN state = 'idle' THEN 'Idle'
        ELSE 'Active'
    END AS status
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY query_start NULLS LAST, backend_start DESC;

-- Option 3: Track role membership changes (requires manual trigger or cron)
CREATE OR REPLACE FUNCTION dba.track_role_changes()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO dba.role_membership_history (server_name, role_name, member_name, member_type, action_type)
        VALUES (dba.get_server_name(), NEW.role_name, NEW.member_name, NEW.member_type, 'ADDED');
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO dba.role_membership_history (server_name, role_name, member_name, member_type, action_type)
        VALUES (dba.get_server_name(), OLD.role_name, OLD.member_name, OLD.member_type, 'REMOVED');
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Note: PostgreSQL doesn't allow triggers on system catalogs
-- Role changes must be tracked via periodic snapshots or external tools

-- Suggested pg_hba.conf for logging (add to end):
-- # Log all connections for auditing
-- host    all     all     0.0.0.0/0    md5    log 100
-- host    all     all     ::0/0        md5    log 100

RAISE NOTICE 'Login audit setup complete.';
RAISE NOTICE '';
RAISE NOTICE 'For full login auditing, configure postgresql.conf:';
RAISE NOTICE '  log_connections = on';
RAISE NOTICE '  log_disconnections = on';
RAISE NOTICE '  log_hostname = on';
RAISE NOTICE '  log_directory = ''pg_log''';
RAISE NOTICE '';
RAISE NOTICE 'Then reload PostgreSQL: pg_ctl reload -D $PGDATA';
