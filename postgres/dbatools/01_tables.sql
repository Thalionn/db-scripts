-- ============================================================================
-- Script: 01_tables.sql
-- Purpose: Create core DBATools tables
-- Usage:   Run after 00_create_schema.sql
-- Notes:   All tables use dba schema
-- ============================================================================

-- Server inventory
CREATE TABLE IF NOT EXISTS dba.server_inventory (
    server_id SERIAL PRIMARY KEY,
    server_name VARCHAR(128) NOT NULL UNIQUE,
    environment VARCHAR(50), -- PROD, UAT, DEV
    is_active BOOLEAN DEFAULT TRUE,
    date_added TIMESTAMP DEFAULT NOW(),
    notes TEXT
);

-- Wait statistics history
CREATE TABLE IF NOT EXISTS dba.wait_stats_history (
    snapshot_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    wait_type VARCHAR(100) NOT NULL,
    wait_count BIGINT,
    wait_time_ms BIGINT,
    signal_wait_time_ms BIGINT
);

CREATE INDEX IF NOT EXISTS idx_wait_stats_capture ON dba.wait_stats_history(capture_time);
CREATE INDEX IF NOT EXISTS idx_wait_stats_type ON dba.wait_stats_history(wait_type);

-- Connection/session history
CREATE TABLE IF NOT EXISTS dba.session_history (
    session_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    pid INTEGER,
    usename VARCHAR(128),
    application_name VARCHAR(256),
    client_addr INET,
    state VARCHAR(50),
    query_start TIMESTAMP,
    query_text TEXT,
    wait_event_type VARCHAR(50),
    wait_event VARCHAR(100)
);

CREATE INDEX IF NOT EXISTS idx_session_capture ON dba.session_history(capture_time);
CREATE INDEX IF NOT EXISTS idx_session_state ON dba.session_history(state);

-- Database size history
CREATE TABLE IF NOT EXISTS dba.database_size_history (
    size_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    datname VARCHAR(128) NOT NULL,
    size_bytes BIGINT,
    size_mb BIGINT GENERATED ALWAYS AS (size_bytes / 1024 / 1024) STORED
);

CREATE INDEX IF NOT EXISTS idx_db_size_capture ON dba.database_size_history(capture_time);
CREATE INDEX IF NOT EXISTS idx_db_size_datname ON dba.database_size_history(datname);

-- Table size history
CREATE TABLE IF NOT EXISTS dba.table_size_history (
    size_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    schemaname VARCHAR(128),
    tablename VARCHAR(128),
    table_size_bytes BIGINT,
    index_size_bytes BIGINT,
    total_size_bytes BIGINT,
    tuple_count BIGINT,
    dead_tuple_count BIGINT
);

CREATE INDEX IF NOT EXISTS idx_table_size_capture ON dba.table_size_history(capture_time);
CREATE INDEX IF NOT EXISTS idx_table_size_table ON dba.table_size_history(schemaname, tablename);

-- Index usage statistics
CREATE TABLE IF NOT EXISTS dba.index_usage_history (
    stat_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    schemaname VARCHAR(128),
    tablename VARCHAR(128),
    indexname VARCHAR(128),
    idx_scan BIGINT,
    idx_tup_read BIGINT,
    idx_tup_fetch BIGINT,
    idx_tup_write BIGINT
);

CREATE INDEX IF NOT EXISTS idx_index_usage_capture ON dba.index_usage_history(capture_time);

-- Security audit - failed logins
CREATE TABLE IF NOT EXISTS dba.login_audit (
    audit_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    audit_time TIMESTAMP DEFAULT NOW(),
    username VARCHAR(128),
    event_type VARCHAR(50), -- LOGIN, FAILED_LOGIN, LOGOUT
    client_addr INET,
    application_name VARCHAR(256),
    is_successful BOOLEAN DEFAULT TRUE,
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_login_audit_time ON dba.login_audit(audit_time);
CREATE INDEX IF NOT EXISTS idx_login_audit_username ON dba.login_audit(username);

-- Security audit - role membership
CREATE TABLE IF NOT EXISTS dba.role_membership_history (
    audit_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    audit_time TIMESTAMP DEFAULT NOW(),
    role_name VARCHAR(128),
    member_name VARCHAR(128),
    member_type VARCHAR(50),
    action_type VARCHAR(20) -- ADDED, REMOVED
);

CREATE INDEX IF NOT EXISTS idx_role_membership_time ON dba.role_membership_history(audit_time);

-- Backup history (if using pgBackRest or similar)
CREATE TABLE IF NOT EXISTS dba.backup_history (
    backup_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    backup_time TIMESTAMP DEFAULT NOW(),
    backup_type VARCHAR(20), -- FULL, DIFF, INCR
    backup_label VARCHAR(256),
    backup_size_bytes BIGINT,
    duration_seconds INTEGER,
    status VARCHAR(50),
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_backup_time ON dba.backup_history(backup_time);
CREATE INDEX IF NOT EXISTS idx_backup_type ON dba.backup_history(backup_type);

-- Index maintenance log
CREATE TABLE IF NOT EXISTS dba.index_maintenance_log (
    maintenance_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    operation_time TIMESTAMP DEFAULT NOW(),
    schemaname VARCHAR(128),
    tablename VARCHAR(128),
    indexname VARCHAR(128),
    operation_type VARCHAR(20), -- REBUILD, REORGANIZE, CREATE, DROP
    duration_seconds INTEGER,
    status VARCHAR(20) DEFAULT 'Success', -- Success, Failed, Skipped
    error_message TEXT
);

CREATE INDEX IF NOT EXISTS idx_index_maint_time ON dba.index_maintenance_log(operation_time);

-- Replication lag tracking
CREATE TABLE IF NOT EXISTS dba.replication_lag_history (
    lag_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    client_addr INET,
    state VARCHAR(50),
    sent_lsn XID8,
    write_lsn XID8,
    flush_lsn XID8,
    replay_lsn XID8,
    lag_bytes BIGINT,
    sync_state VARCHAR(20)
);

CREATE INDEX IF NOT EXISTS idx_replication_lag_capture ON dba.replication_lag_history(capture_time);

-- Configuration changes
CREATE TABLE IF NOT EXISTS dba.config_changes (
    change_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    change_time TIMESTAMP DEFAULT NOW(),
    setting_name VARCHAR(128),
    old_value TEXT,
    new_value TEXT,
    changed_by VARCHAR(128)
);

CREATE INDEX IF NOT EXISTS idx_config_changes_time ON dba.config_changes(change_time);

-- Alert configuration
CREATE TABLE IF NOT EXISTS dba.alert_configuration (
    alert_id SERIAL PRIMARY KEY,
    alert_name VARCHAR(100) NOT NULL UNIQUE,
    alert_type VARCHAR(50),
    check_query TEXT,
    threshold_value INTEGER,
    is_enabled BOOLEAN DEFAULT TRUE,
    notify_email VARCHAR(256),
    notification_message TEXT,
    last_checked TIMESTAMP,
    last_triggered TIMESTAMP,
    trigger_count INTEGER DEFAULT 0
);

-- Performance baselines
CREATE TABLE IF NOT EXISTS dba.performance_baseline (
    baseline_id SERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    metric_name VARCHAR(128),
    metric_value NUMERIC,
    baseline_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_baseline_server ON dba.performance_baseline(server_name, metric_name);

-- Query statistics snapshot
CREATE TABLE IF NOT EXISTS dba.query_stats_snapshot (
    stats_id BIGSERIAL PRIMARY KEY,
    server_name VARCHAR(128),
    capture_time TIMESTAMP DEFAULT NOW(),
    queryid BIGINT,
    calls BIGINT,
    total_time_ms BIGINT,
    min_time_ms BIGINT,
    max_time_ms BIGINT,
    mean_time_ms NUMERIC,
    stddev_time_ms NUMERIC,
    rows BIGINT,
    shared_blks_hit BIGINT,
    shared_blks_read BIGINT,
    shared_blks_written BIGINT,
    temp_blks_read BIGINT,
    temp_blks_written BIGINT,
    query_text TEXT
);

CREATE INDEX IF NOT EXISTS idx_query_stats_capture ON dba.query_stats_snapshot(capture_time);
CREATE INDEX IF NOT EXISTS idx_query_stats_queryid ON dba.query_stats_snapshot(queryid);

RAISE NOTICE 'Core tables created successfully.';
