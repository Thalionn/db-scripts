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
