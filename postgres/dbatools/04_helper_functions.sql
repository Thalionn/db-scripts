-- ============================================================================
-- Script: 04_helper_functions.sql
-- Purpose: Utility functions for DBATools
-- Usage:   Run after 03_views.sql
-- ============================================================================

-- Format bytes to human readable
CREATE OR REPLACE FUNCTION dba.format_bytes(p_bytes BIGINT)
RETURNS TEXT AS $$
BEGIN
    RETURN CASE
        WHEN p_bytes >= 1099511627776 THEN ROUND(p_bytes::NUMERIC / 1099511627776, 2) || ' TB'
        WHEN p_bytes >= 1073741824 THEN ROUND(p_bytes::NUMERIC / 1073741824, 2) || ' GB'
        WHEN p_bytes >= 1048576 THEN ROUND(p_bytes::NUMERIC / 1048576, 2) || ' MB'
        WHEN p_bytes >= 1024 THEN ROUND(p_bytes::NUMERIC / 1024, 2) || ' KB'
        ELSE p_bytes || ' bytes'
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Get database age in days
CREATE OR REPLACE FUNCTION dba.get_database_age(p_datname VARCHAR(128))
RETURNS INTEGER AS $$
DECLARE
    v_oldest_date DATE;
BEGIN
    SELECT MIN(backup_time)::DATE INTO v_oldest_date
    FROM dba.backup_history
    WHERE backup_type = 'FULL' AND status = 'Success';
    
    IF v_oldest_date IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN CURRENT_DATE - v_oldest_date;
END;
$$ LANGUAGE plpgsql;

-- Calculate growth rate
CREATE OR REPLACE FUNCTION dba.calculate_growth_rate(
    p_datname VARCHAR(128),
    p_days INTEGER DEFAULT 30
)
RETURNS NUMERIC AS $$
DECLARE
    v_first_size BIGINT;
    v_last_size BIGINT;
    v_first_date TIMESTAMP;
    v_last_date TIMESTAMP;
BEGIN
    SELECT size_bytes, capture_time 
    INTO v_first_size, v_first_date
    FROM dba.database_size_history
    WHERE datname = p_datname
    ORDER BY capture_time ASC
    LIMIT 1;
    
    SELECT size_bytes, capture_time 
    INTO v_last_size, v_last_date
    FROM dba.database_size_history
    WHERE datname = p_datname
    ORDER BY capture_time DESC
    LIMIT 1;
    
    IF v_first_size IS NULL OR v_last_size IS NULL THEN
        RETURN NULL;
    END IF;
    
    RETURN ROUND(
        (v_last_size - v_first_size)::NUMERIC / 
        NULLIF(EXTRACT(EPOCH FROM (v_last_date - v_first_date)) / 86400, 0),
        2
    );
END;
$$ LANGUAGE plpgsql;

-- Check if backup chain is intact
CREATE OR REPLACE FUNCTION dba.check_backup_chain_status(p_datname VARCHAR(128))
RETURNS VARCHAR(20) AS $$
DECLARE
    v_last_full TIMESTAMP;
    v_last_diff TIMESTAMP;
    v_last_log TIMESTAMP;
BEGIN
    SELECT MAX(backup_time) INTO v_last_full
    FROM dba.backup_history
    WHERE datname = p_datname AND backup_type = 'FULL' AND status = 'Success';
    
    SELECT MAX(backup_time) INTO v_last_diff
    FROM dba.backup_history
    WHERE datname = p_datname AND backup_type = 'DIFF' AND status = 'Success';
    
    SELECT MAX(backup_time) INTO v_last_log
    FROM dba.backup_history
    WHERE datname = p_datname AND backup_type = 'INCR' AND status = 'Success';
    
    IF v_last_full IS NULL THEN
        RETURN 'NO_BACKUP';
    END IF;
    
    IF v_last_log IS NULL OR v_last_log < NOW() - INTERVAL '1 hour' THEN
        RETURN 'LOG_GAP';
    END IF;
    
    IF v_last_diff IS NULL AND v_last_full < NOW() - INTERVAL '1 day' THEN
        RETURN 'NO_RECENT_DIFF';
    END IF;
    
    RETURN 'OK';
END;
$$ LANGUAGE plpgsql;

-- Get connection limit status
CREATE OR REPLACE FUNCTION dba.get_connection_status()
RETURNS TABLE(
    current_connections BIGINT,
    max_connections BIGINT,
    usage_pct NUMERIC,
    status VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    WITH conn_stats AS (
        SELECT 
            COUNT(*)::BIGINT AS current_conn,
            (SELECT setting::INT FROM pg_settings WHERE name = 'max_connections') AS max_conn
        FROM pg_stat_activity
        WHERE pid <> pg_backend_pid()
    )
    SELECT 
        cs.current_conn,
        cs.max_conn,
        ROUND(100.0 * cs.current_conn / cs.max_conn, 2) AS usage_pct,
        CASE 
            WHEN 100.0 * cs.current_conn / cs.max_conn > 90 THEN 'CRITICAL'
            WHEN 100.0 * cs.current_conn / cs.max_conn > 75 THEN 'WARNING'
            ELSE 'OK'
        END AS status
    FROM conn_stats cs;
END;
$$ LANGUAGE plpgsql;

-- Alert check function
CREATE OR REPLACE FUNCTION dba.check_alerts()
RETURNS TABLE(alert_name VARCHAR, alert_message TEXT, severity VARCHAR) AS $$
DECLARE
    v_conn_status RECORD;
    v_failed_logins RECORD;
BEGIN
    -- Check connection limit
    FOR v_conn_status IN SELECT * FROM dba.get_connection_status() LOOP
        IF v_conn_status.usage_pct > 80 THEN
            RETURN QUERY SELECT 
                'Connection Limit'::VARCHAR,
                ('Connections at ' || v_conn_status.usage_pct || '%. Current: ' || v_conn_status.current_connections || ', Max: ' || v_conn_status.max_connections)::TEXT,
                CASE 
                    WHEN v_conn_status.usage_pct > 95 THEN 'CRITICAL'
                    ELSE 'WARNING'
                END;
        END IF;
    END LOOP;
    
    -- Check failed logins
    FOR v_failed_logins IN 
        SELECT COUNT(*) AS cnt, MAX(audit_time) AS last_attempt
        FROM dba.login_audit
        WHERE event_type = 'FAILED_LOGIN'
          AND audit_time >= NOW() - INTERVAL '1 hour'
    LOOP
        IF v_failed_logins.cnt >= 5 THEN
            RETURN QUERY SELECT 
                'Failed Logins'::VARCHAR,
                (v_failed_logins.cnt || ' failed login attempts in last hour. Last: ' || v_failed_logins.last_attempt)::TEXT,
                'WARNING'::VARCHAR;
        END IF;
    END LOOP;
    
    -- Check replication lag
    IF EXISTS (SELECT 1 FROM pg_stat_replication WHERE pg_wal_lsn_diff(sent_lsn, replay_lsn) > 104857600) THEN
        RETURN QUERY SELECT 
            'Replication Lag'::VARCHAR,
            'Replication lag exceeds 100MB on one or more standbys'::TEXT,
            'WARNING'::VARCHAR;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Generate weekly summary report
CREATE OR REPLACE FUNCTION dba.generate_weekly_summary()
RETURNS TABLE(report_section TEXT, report_line TEXT) AS $$
BEGIN
    RETURN QUERY SELECT '=== SERVER OVERVIEW ==='::TEXT, ''::TEXT;
    
    RETURN QUERY SELECT 'Current Connections: '::TEXT, 
        (SELECT COUNT(*)::TEXT FROM pg_stat_activity WHERE pid <> pg_backend_pid());
    
    RETURN QUERY SELECT ''::TEXT, ''::TEXT;
    RETURN QUERY SELECT '=== TOP WAITS (Last 24h) ==='::TEXT, ''::TEXT;
    
    RETURN QUERY 
    SELECT w.wait_type::TEXT, 
           ('Count: ' || SUM(w.wait_count) || ', Total: ' || SUM(w.wait_time_ms) || 'ms')::TEXT
    FROM dba.wait_stats_history w
    WHERE w.capture_time >= NOW() - INTERVAL '24 hours'
    GROUP BY w.wait_type
    ORDER BY SUM(w.wait_time_ms) DESC
    LIMIT 10;
    
    RETURN QUERY SELECT ''::TEXT, ''::TEXT;
    RETURN QUERY SELECT '=== DATABASE SIZES ==='::TEXT, ''::TEXT;
    
    RETURN QUERY 
    SELECT ds.datname::TEXT, 
           (ROUND(ds.size_mb::NUMERIC / 1024, 2) || ' GB')::TEXT
    FROM dba.database_size_history ds
    WHERE ds.capture_time = (SELECT MAX(capture_time) FROM dba.database_size_history)
    ORDER BY ds.size_mb DESC;
    
    RETURN QUERY SELECT ''::TEXT, ''::TEXT;
    RETURN QUERY SELECT '=== FAILED LOGINS (Last 7 days) ==='::TEXT, ''::TEXT;
    
    RETURN QUERY 
    SELECT la.username::TEXT, 
           (COUNT(*) || ' attempts')::TEXT
    FROM dba.login_audit la
    WHERE la.event_type = 'FAILED_LOGIN'
      AND la.audit_time >= NOW() - INTERVAL '7 days'
    GROUP BY la.username
    ORDER BY COUNT(*) DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

-- Vacuum recommendation
CREATE OR REPLACE FUNCTION dba.get_vacuum_recommendations()
RETURNS TABLE(
    schemaname NAME,
    relname NAME,
    relkind CHAR,
    n_dead_tup BIGINT,
    n_live_tup BIGINT,
    dead_tuple_pct NUMERIC,
    last_vacuum TIMESTAMP,
    last_autovacuum TIMESTAMP,
    recommendation TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        s.schemaname,
        s.relname,
        s.relkind,
        s.n_dead_tup,
        s.n_live_tup,
        CASE WHEN s.n_live_tup > 0 
             THEN ROUND(100.0 * s.n_dead_tup / (s.n_live_tup + s.n_dead_tup), 2)
             ELSE 0 
        END AS dead_tuple_pct,
        s.last_vacuum,
        s.last_autovacuum,
        CASE
            WHEN s.n_dead_tup > 10000 AND s.last_autovacuum < NOW() - INTERVAL '1 day' THEN 'AUTOVACUUM NEEDED'
            WHEN s.n_dead_tup > 50000 THEN 'MANUAL VACUUM RECOMMENDED'
            ELSE 'OK'
        END AS recommendation
    FROM pg_stat_user_tables s
    WHERE s.schemaname NOT IN ('pg_catalog', 'information_schema')
      AND s.n_dead_tup > 1000
    ORDER BY s.n_dead_tup DESC;
END;
$$ LANGUAGE plpgsql;

RAISE NOTICE 'Helper functions created successfully.';
