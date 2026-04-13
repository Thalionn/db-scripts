# Oracle Diagnostic Scripts

Scripts tested on Oracle 11g through 21c.

## Session & Connection Monitoring

| Script | Description |
|--------|-------------|
| `sessions_active.sql` | Current session inventory by user/program |
| `blocking_sessions.sql` | Lock wait chains and blockers |

## Space Management

| Script | Description |
|--------|-------------|
| `tablespace_check.sql` | Space utilization with alert thresholds |
| `temp_usage.sql` | Temporary tablespace consumption |
| `undo_usage.sql` | Undo retention analysis |

## Performance

| Script | Description |
|--------|-------------|
| `wait_events.sql` | Top wait events (bottleneck identification) |

## Health Checks

| Script | Description |
|--------|-------------|
| `invalid_objects.sql` | Objects requiring recompilation |
| `fragmentation.sql` | Table chain/fragmentation detection |
| `duplicate_indexes.sql` | Duplicate index detection |
| `generate_documentation.sql` | Database documentation generator |

## Prerequisites

Most scripts require one of:
- `DBA` role
- `SELECT_CATALOG_ROLE`
- Direct access to `V$` views (AS SYSDBA)

```sql
-- Verify access
SELECT * FROM v$instance;
SELECT * FROM dba_tablespaces;
```

## Quick Test

| Script | Description |
|--------|-------------|
| `quick_health_check.sql` | Consolidated health check |

## Configuration

| Script | Description |
|--------|-------------|
| `optimal_settings.sql` | Apply community best practices |

## DBATools

| Folder | Description |
|--------|-------------|
| `dbatools/` | Centralized monitoring database |
