# SQL Server Diagnostic Scripts

Scripts tested on SQL Server 2016 through 2022.

## Sessions & Blocking

| Script | Description |
|--------|-------------|
| `active_sessions.sql` | Current SPID inventory |
| `blocking_chains.sql` | Blocking session tree (recursive) |
| `wait_stats.sql` | Aggregated wait type statistics |

## Index Maintenance

| Script | Description |
|--------|-------------|
| `index_fragmentation.sql` | Fragmentation analysis and recommendations |

## Storage

| Script | Description |
|--------|-------------|
| `database_size.sql` | File space consumption |
| `autogrowth_events.sql` | Autogrowth audit log |

## Jobs

| Script | Description |
|--------|-------------|
| `job_history.sql` | Recent Agent job execution |

## Prerequisites

Most scripts require:
- View Server State permission
- Access to msdb database (for job_history.sql)

```sql
-- Verify permissions
SELECT HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE');

-- Check msdb access
SELECT * FROM msdb.dbo.sysjobs;
```

## Quick Test

```bash
sqlcmd -S localhost -E -i active_sessions.sql
```
