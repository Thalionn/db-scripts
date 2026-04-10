# PostgreSQL DBATools

A monitoring and maintenance database for PostgreSQL instances.

## Installation Order

Run scripts in sequence on each PostgreSQL instance:

| Script | Purpose |
|--------|---------|
| `00_create_schema.sql` | Create dba schema and extensions |
| `01_tables.sql` | Create all logging tables |
| `02_functions.sql` | Collection functions |
| `03_views.sql` | Diagnostic views |
| `04_helper_functions.sql` | Utility functions |
| `05_pgagent_jobs.sql` | Scheduled collection jobs |
| `06_login_audit_setup.sql` | Connection logging setup |

## Prerequisites

- PostgreSQL 12 or later
- `pg_stat_statements` extension enabled
- Superuser or sufficient privileges
- pgAgent (optional, for scheduled jobs)

### Enable pg_stat_statements

```sql
CREATE EXTENSION pg_stat_statements;
```

### Enable pgAgent (optional)

```bash
# Install pgAgent
# Linux: pgadmin4 or postgresql-15-pgagent
# Or build from source

# Create extension
CREATE EXTENSION pgagent;
```

## Installation

```bash
# Connect as superuser
psql -U postgres -d postgres -f 00_create_schema.sql
psql -U postgres -d postgres -f 01_tables.sql
# ... continue through 06_login_audit_setup.sql
```

## What Gets Collected

### Performance Monitoring
- Wait statistics (15-minute intervals)
- Session snapshots (5-minute intervals)
- Query statistics (30-minute intervals)
- Database/table sizes (hourly)
- Index usage

### Replication
- Replication lag tracking
- Standby status

### Security
- Role membership snapshots
- Connection tracking

## Key Views

```sql
-- Current active sessions
SELECT * FROM dba.v_current_waits;

-- Blocking sessions
SELECT * FROM dba.v_blocking_sessions;

-- Table bloat
SELECT * FROM dba.v_table_bloat;

-- Unused indexes
SELECT * FROM dba.v_unused_indexes;

-- Replication status
SELECT * FROM dba.v_replication_status;

-- Failed logins
SELECT * FROM dba.v_failed_logins_24h;

-- Slow queries
SELECT * FROM dba.v_slow_queries;

-- Database growth
SELECT * FROM dba.v_database_growth;

-- Check alerts
SELECT * FROM dba.check_alerts();

-- Weekly summary
SELECT * FROM dba.generate_weekly_summary();
```

## Configuration

### Set Server Name

```sql
-- Optional: Set a friendly name for this server
ALTER DATABASE postgres SET dba.server_name = 'prod-postgres-01';
```

### Adjust Retention

```sql
-- Purge data older than 30 days
SELECT * FROM dba.purge_old_data(p_retention_days := 30);
```

### Alert Email Setup

PostgreSQL doesn't have built-in email. Configure alerts using:
- pgAlert (pgAdmin)
- check_postgres (Nagios/Icinga)
- pgMonitor (Prometheus/Grafana)
- Custom scripts with cron

## Cron Alternative (if not using pgAgent)

```bash
# Add to crontab for servers without pgAgent
*/15 * * * * psql -U postgres -c "SELECT dba.capture_wait_stats();"
*/5 * * * * psql -U postgres -c "SELECT dba.capture_session_snapshot();"
0 * * * * psql -U postgres -c "SELECT dba.capture_database_sizes();"
*/30 * * * * psql -U postgres -c "SELECT dba.capture_query_stats(10);"
0 0 * * * psql -U postgres -c "SELECT dba.purge_old_data(30);"
```

## Notes

- All tables use the `dba` schema
- Functions run with SECURITY DEFINER where needed
- Some views require superuser for full access
- Test in non-production first
- Adjust thresholds in views for your environment
