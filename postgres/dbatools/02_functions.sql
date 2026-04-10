-- ============================================================================
-- Script: 02_functions.sql
-- Purpose: Stored functions for DBATools data collection
-- Usage:   Run after 01_tables.sql
-- Notes:   These are called by pgAgent jobs or cron
-- ============================================================================

-- Get current server name (helper)
CREATE OR REPLACE FUNCTION dba.get_server_name()
RETURNS VARCHAR(128) AS $$
BEGIN
    RETURN COALESCE(
        NULLIF(current_setting('dba.server_name', TRUE), ''),
        inet_server_addr()::VARCHAR
    );
END;
$$ LANGUAGE plpgsql;

-- Capture wait statistics
CREATE OR REPLACE FUNCTION dba.capture_wait_stats()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.wait_stats_history (server_name, wait_type, wait_count, wait_time_ms, signal_wait_time_ms)
    SELECT 
        dba.get_server_name(),
        wait_event_type || ':' || COALESCE(wait_event, 'None'),
        SUM(wait_count)::BIGINT,
        (SUM(wait_time_ms))::BIGINT,
        (SUM(signal_wait_time_ms))::BIGINT
    FROM pg_stat_activity
    CROSS JOIN LATERAL pg_stat_get_wait_events(s.pid) AS we
    GROUP BY wait_event_type, wait_event;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture current sessions
CREATE OR REPLACE FUNCTION dba.capture_session_snapshot()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.session_history (
        server_name, pid, usename, application_name, client_addr, 
        state, query_start, query_text, wait_event_type, wait_event
    )
    SELECT 
        dba.get_server_name(),
        p.pid,
        p.usename,
        p.application_name,
        p.client_addr,
        p.state,
        p.query_start,
        LEFT(p.query, 500),
        p.wait_event_type,
        p.wait_event
    FROM pg_stat_activity p
    WHERE p.pid <> pg_backend_pid();
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture database sizes
CREATE OR REPLACE FUNCTION dba.capture_database_sizes()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.database_size_history (server_name, datname, size_bytes)
    SELECT 
        dba.get_server_name(),
        d.datname,
        pg_database_size(d.datname)
    FROM pg_database d
    WHERE d.datistemplate = FALSE;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture table and index sizes
CREATE OR REPLACE FUNCTION dba.capture_table_sizes()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.table_size_history (
        server_name, schemaname, tablename, 
        table_size_bytes, index_size_bytes, total_size_bytes,
        tuple_count, dead_tuple_count
    )
    SELECT 
        dba.get_server_name(),
        schemaname,
        tablename,
        pg_total_relation_size(schemaname || '.' || tablename) - pg_indexes_size(schemaname || '.' || tablename),
        pg_indexes_size(schemaname || '.' || tablename),
        pg_total_relation_size(schemaname || '.' || tablename),
        n_live_tup,
        n_dead_tup
    FROM pg_stat_user_tables
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema');
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture index usage statistics
CREATE OR REPLACE FUNCTION dba.capture_index_usage()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.index_usage_history (
        server_name, schemaname, tablename, indexname,
        idx_scan, idx_tup_read, idx_tup_fetch, idx_tup_write
    )
    SELECT 
        dba.get_server_name(),
        schemaname,
        tablename,
        indexname,
        idx_scan,
        idx_tup_read,
        idx_tup_fetch,
        idx_tup_write
    FROM pg_stat_user_indexes
    WHERE schemaname NOT IN ('pg_catalog', 'information_schema');
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture replication lag
CREATE OR REPLACE FUNCTION dba.capture_replication_lag()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.replication_lag_history (
        server_name, client_addr, state, 
        sent_lsn, write_lsn, flush_lsn, replay_lsn,
        lag_bytes, sync_state
    )
    SELECT 
        dba.get_server_name(),
        client_addr,
        state,
        sent_lsn,
        write_lsn,
        flush_lsn,
        replay_lsn,
        pg_wal_lsn_diff(sent_lsn, replay_lsn),
        sync_state
    FROM pg_stat_replication;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Capture query statistics
CREATE OR REPLACE FUNCTION dba.capture_query_stats(p_min_calls INTEGER DEFAULT 10)
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.query_stats_snapshot (
        server_name, queryid, calls, total_time_ms, min_time_ms, max_time_ms,
        mean_time_ms, stddev_time_ms, rows,
        shared_blks_hit, shared_blks_read, shared_blks_written,
        temp_blks_read, temp_blks_written, query_text
    )
    SELECT 
        dba.get_server_name(),
        queryid,
        calls,
        total_exec_time::BIGINT,
        min_exec_time::BIGINT,
        max_exec_time::BIGINT,
        mean_exec_time,
        stddev_exec_time,
        rows,
        shared_blks_hit,
        shared_blks_read,
        shared_blks_written,
        temp_blks_read,
        temp_blks_written,
        LEFT(query, 500)
    FROM pg_stat_statements
    WHERE calls >= p_min_calls
    ORDER BY total_exec_time DESC
    LIMIT 100;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Log failed login attempt
CREATE OR REPLACE FUNCTION dba.log_failed_login(
    p_username VARCHAR(128),
    p_error_message TEXT
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO dba.login_audit (server_name, username, event_type, is_successful, error_message)
    VALUES (dba.get_server_name(), p_username, 'FAILED_LOGIN', FALSE, p_error_message);
END;
$$ LANGUAGE plpgsql;

-- Capture role membership
CREATE OR REPLACE FUNCTION dba.capture_role_membership()
RETURNS TABLE(rows_inserted BIGINT) AS $$
DECLARE
    v_rows BIGINT;
BEGIN
    INSERT INTO dba.role_membership_history (server_name, role_name, member_name, member_type, action_type)
    SELECT 
        dba.get_server_name(),
        r.rolname AS role_name,
        m.rolname AS member_name,
        CASE 
            WHEN m.roltype = 'ROLE' THEN 'Role'
            WHEN m.rolsuper = TRUE THEN 'Superuser'
            ELSE 'User'
        END AS member_type,
        'CURRENT' AS action_type
    FROM pg_roles r
    JOIN pg_auth_members am ON r.oid = am.roleid
    JOIN pg_roles m ON am.member = m.oid;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    RETURN QUERY SELECT v_rows;
END;
$$ LANGUAGE plpgsql;

-- Purge old data
CREATE OR REPLACE FUNCTION dba.purge_old_data(
    p_retention_days INTEGER DEFAULT 30,
    p_table_name VARCHAR(50) DEFAULT NULL
)
RETURNS TABLE(purged_table VARCHAR(50), rows_deleted BIGINT) AS $$
DECLARE
    v_cutoff_date TIMESTAMP;
    v_sql TEXT;
    v_rows BIGINT;
    v_table VARCHAR(50);
BEGIN
    v_cutoff_date := NOW() - (p_retention_days || ' days')::INTERVAL;
    
    -- Tables to purge
    FOREACH v_table IN ARRAY ARRAY[
        'wait_stats_history',
        'session_history',
        'database_size_history',
        'table_size_history',
        'index_usage_history',
        'replication_lag_history',
        'query_stats_snapshot',
        'login_audit'
    ]
    LOOP
        IF p_table_name IS NULL OR p_table_name = v_table THEN
            v_sql := format('DELETE FROM dba.%I WHERE capture_time < %L', v_table, v_cutoff_date);
            IF v_table = 'login_audit' THEN
                v_sql := format('DELETE FROM dba.%I WHERE audit_time < %L', v_table, v_cutoff_date);
            END IF;
            
            EXECUTE v_sql;
            GET DIAGNOSTICS v_rows = ROW_COUNT;
            
            IF v_rows > 0 THEN
                RETURN QUERY SELECT v_table, v_rows;
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Index maintenance - check bloat
CREATE OR REPLACE FUNCTION dba.check_index_bloat(
    p_min_bloat_pct INTEGER DEFAULT 20,
    p_min_size_mb NUMERIC DEFAULT 1
)
RETURNS TABLE(
    schemaname NAME,
    tablename NAME,
    indexname NAME,
    index_size_bytes BIGINT,
    bloat_pct NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    WITH constants AS (
        SELECT current_setting('block_size')::NUMERIC AS bs
    ),
    index_info AS (
        SELECT
            schemaname,
            tablename,
            indexname,
            (index_tuple_stats).index_size AS index_size_bytes,
            (index_tuple_stats).live_tuple_count AS live_tuples,
            (index_tuple_stats).dead_tuple_count AS dead_tuples
        FROM pg_stat_user_indexes ui
        JOIN constants c ON TRUE
        CROSS JOIN LATERAL pg_index_tuple_stats(ui.schemaname, ui.indexrelid) AS index_tuple_stats
    )
    SELECT
        schemaname,
        tablename,
        indexname,
        index_size_bytes,
        CASE 
            WHEN live_tuples > 0 
            THEN ROUND(100 * (1 - live_tuples::NUMERIC / (live_tuples + dead_tuples + 1)), 2)
            ELSE 0
        END AS bloat_pct
    FROM index_info
    WHERE index_size_bytes / 1024 / 1024 >= p_min_size_mb
      AND CASE 
            WHEN live_tuples > 0 
            THEN 100 * (1 - live_tuples::NUMERIC / (live_tuples + dead_tuples + 1))
            ELSE 0
          END >= p_min_bloat_pct
    ORDER BY index_size_bytes DESC;
END;
$$ LANGUAGE plpgsql;

-- REINDEX table
CREATE OR REPLACE FUNCTION dba.reindex_table(
    p_schemaname NAME,
    p_tablename NAME
)
RETURNS VOID AS $$
DECLARE
    v_index RECORD;
BEGIN
    FOR v_index IN 
        SELECT indexname 
        FROM pg_indexes 
        WHERE schemaname = p_schemaname AND tablename = p_tablename
    LOOP
        EXECUTE format('REINDEX INDEX %I.%I', p_schemaname, v_index.indexname);
        
        INSERT INTO dba.index_maintenance_log (
            server_name, schemaname, tablename, indexname, operation_type, duration_seconds, status
        )
        VALUES (
            dba.get_server_name(), p_schemaname, p_tablename, v_index.indexname,
            'REINDEX', 0, 'Success'
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'Functions created successfully.';
