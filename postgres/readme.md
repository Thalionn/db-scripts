# PostgreSQL Diagnostic Scripts

Scripts tested on PostgreSQL 12 through 16.

## Connection & Sessions

| Script | Description |
|--------|-------------|
| `sessions_current.sql` | Active connections by state and query |
| `locks_blocking.sql` | Lock wait chains |

## Performance

| Script | Description |
|--------|-------------|
| `slow_queries.sql` | Queries running longer than threshold |
| `cache_hit_ratio.sql` | Buffer cache efficiency |
| `replication_lag.sql` | Streaming replication status |

## Storage & Maintenance

| Script | Description |
|--------|-------------|
| `table_size.sql` | Storage breakdown by table |
| `bloat_check.sql` | Table bloat detection |
| `index_usage.sql` | Unused/low-usage indexes |
| `duplicate_indexes.sql` | Duplicate/redundant index detection |

## Documentation

| Script | Description |
|--------|-------------|
| `generate_documentation.sql` | Generate markdown documentation |

## Quick Health Check

| Script | Description |
|--------|-------------|
| `quick_health_check.sql` | Consolidated health check |

## Shell Scripts

| Script | Description |
|--------|-------------|
| `scripts/run_health_check.sh` | Run health check and optionally email |
| `scripts/backup.sh` | Automated backup with retention |
| `scripts/index_maintenance.sh` | Analyze and optimize indexes |
| `scripts/setup_cron.sh` | Install cron jobs for automation |

## Configuration

| Script | Description |
|--------|-------------|
| `optimal_settings.sql` | Apply community best practices |

## Prerequisites

Some scripts require the `pgstattuple` extension:

```sql
CREATE EXTENSION IF NOT EXISTS pgstattuple;
```

Verify access:

```bash
psql -c "SELECT version();"
psql -c "SELECT * FROM pg_stat_activity LIMIT 1;"
```

## Quick Test

```bash
psql -f sessions_current.sql
```
