-- ============================================================================
-- Script: optimal_settings.sql
-- Purpose: Apply PostgreSQL best practice settings
-- Usage:   psql -U postgres -f optimal_settings.sql
-- Notes:   Review each setting before applying in production
-- ============================================================================

\echo '============================================================'
\echo 'PostgreSQL Optimal Configuration Script'
\echo 'Based on community best practices'
\echo '============================================================'

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 1: Memory Settings'
\echo '------------------------------------------------------------'

\echo ''
\echo 'Current memory settings:'
SHOW shared_buffers;
SHOW work_mem;
SHOW maintenance_work_mem;
SHOW effective_cache_size;
SHOW temp_buffers;

\echo ''
\echo 'Recommended settings (adjust based on available RAM):'
\echo '-- For a dedicated server with 16GB RAM:'
\echo "SET shared_buffers = '4GB';"
\echo "SET work_mem = '64MB';"
\echo "SET maintenance_work_mem = '1GB';"
\echo "SET effective_cache_size = '12GB';"
\echo "SET temp_buffers = '16MB';"

\echo ''
\echo 'To persist across restarts, add to postgresql.conf:'
\echo 'shared_buffers = 4GB  # 25% of available RAM'
\echo 'work_mem = 64MB'
\echo 'maintenance_work_mem = 1GB'
\echo 'effective_cache_size = 12GB  # 75% of available RAM'

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 2: Connection Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW max_connections;
SHOW superuser_reserved_connections;

\echo ''
\echo 'Recommended: max_connections = 100-300 for typical workloads'
\echo 'Use connection pooling (PgBouncer/pgpool-II) for higher'

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 3: Write Ahead Log (WAL) Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW wal_level;
SHOW max_wal_size;
SHOW min_wal_size;
SHOW checkpoint_completion_target;

\echo ''
\echo 'Recommended for performance:'
\echo "SET wal_level = 'replica';  -- or 'minimal' if not replicating"
\echo "SET max_wal_size = '1GB';"
\echo "SET min_wal_size = '80MB';"
\echo "SET checkpoint_completion_target = 0.9;"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 4: Query Planner Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW random_page_cost;
SHOW effective_io_concurrency;
SHOW default_statistics_target;

\echo ''
\echo 'Recommended for SSDs:'
\echo "SET random_page_cost = 1.1;"
\echo "SET effective_io_concurrency = 200;"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 5: Autovacuum Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW autovacuum;
SHOW autovacuum_max_workers;
SHOW autovacuum_naptime;
SHOW autovacuum_vacuum_threshold;
SHOW autvacuum_analyze_threshold;

\echo ''
\echo 'Recommended:'
\echo "SET autovacuum = on;"
\echo "SET autovacuum_max_workers = 4;  -- 1 per 4 cores"
\echo "SET autovacuum_naptime = '1min';"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 6: Logging Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW log_destination;
SHOW logging_collector;
SHOW log_directory;
SHOW log_rotation_size;

\echo ''
\echo 'Recommended:'
\echo "SET log_destination = 'stderr';"
\echo "SET logging_collector = on;"
\echo "SET log_directory = 'log';"
\echo "SET log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log';"
\echo "SET log_rotation_age = '1d';"
\echo "SET log_rotation_size = '100MB';"
\echo "SET log_min_duration_statement = 1000;  -- log queries > 1s"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 7: Lock and Statement Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW deadlock_timeout;
SHOW statement_timeout;
SHOW lock_timeout;

\echo ''
\echo 'Recommended:'
\echo "SET deadlock_timeout = '1s';"
\echo "SET statement_timeout = '30s';  -- or 0 for unlimited"
\echo "SET lock_timeout = '10s';"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 8: Network and Compression'
\echo '------------------------------------------------------------'

\echo ''
SHOW listen_addresses;
SHOW port;
SHOW shared_buffers;

\echo ''
\echo 'Enable compression for bulk data:'
\echo "SET wal_compression = on;"

\echo ''
\echo 'Enable huge pages (Linux):'
\echo 'Add to /etc/sysctl.conf: kernel.shmmax = X'
\echo 'Add to postgresql.conf: huge_pages = try'

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 9: Replication Settings'
\echo '------------------------------------------------------------'

\echo ''
SHOW max_replication_slots;
SHOW wal_sender_timeout;
SHOW wal_receiver_timeout;

\echo ''
\echo 'Recommended:'
\echo "SET max_replication_slots = 10;"
\echo "SET wal_sender_timeout = '60s';"
\echo "SET wal_receiver_timeout = '60s';"

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 10: Extensions to Enable'
\echo '------------------------------------------------------------'

\echo ''
\echo 'Enable recommended extensions:'

SELECT 'CREATE EXTENSION IF NOT EXISTS ' || extname || ';' AS extension_to_enable
FROM pg_extension
WHERE extname IN ('pg_stat_statements', 'pg_buffercache', 'pgstattuple', 'pg_visibility', 'pageinspect')
ORDER BY extname;

\echo ''
\echo '------------------------------------------------------------'
\echo 'SECTION 11: Verify Current Settings'
\echo '------------------------------------------------------------'

\echo ''
\echo 'Current PostgreSQL version:'
SELECT version();

\echo ''
\echo 'Database size:'
SELECT datname, pg_size_pretty(pg_database_size(datname)) AS size
FROM pg_database WHERE datistemplate = false;

\echo ''
\echo '============================================================'
\echo 'REVIEW MANUALLY BEFORE APPLYING:'
\echo '============================================================'
\echo ''
\echo '1. postgresql.conf settings to review:'
\echo '   - shared_buffers (25% of RAM)'
\echo '   - work_mem (per connection)'
\echo '   - max_connections (consider pooling)'
\echo '   - checkpoint settings'
\echo ''
\echo '2. pg_hba.conf for authentication'
\echo ''
\echo '3. Connection pooling (PgBouncer)'
\echo ''
\echo '4. Backup retention policy'
\echo ''
\echo '5. Streaming replication slots if using HA'
\echo ''
\echo '============================================================'
\echo 'Configuration script complete'
\echo '============================================================'
