-- ============================================================================
-- Script: replication_lag.sql
-- Purpose: Streaming replication lag monitoring
-- Usage:   Run on primary; check standby nodes for lag
-- Notes:   High lag may indicate network issues or standby load
-- ============================================================================

SELECT 
    client_addr AS standby_address,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes,
    pg_size_pretty(pg_wal_lsn_diff(sent_lsn, replay_lsn)) AS lag_size,
    sync_state
FROM pg_stat_replication
ORDER BY lag_bytes DESC;
