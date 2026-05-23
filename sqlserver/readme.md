# SQL Server Diagnostic Scripts

Scripts tested on SQL Server 2016 through 2022.

## Utility Functions

| Script | Description |
|--------|-------------|
| `helper_functions.sql` | Common utility functions for all diagnostic scripts (run once) |

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

## Quick Health Check

| Script | Description |
|--------|-------------|
| `quick_health_check.sql` | Consolidated health check |

## Configuration

| Script | Description |
|--------|-------------|
| `optimal_settings.sql` | Apply community best practices |

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

## Usage Notes (Standalone Scripts)

### Order of Deployment (Recommended)
1. **helper_functions.sql** - Creates utility functions for cleaner script design
2. Any standalone diagnostic script at any time (they are independent)

### For Monitoring Needs
- `tempdb_contention.sql` - Add to your monitoring routine; run weekly
- `quick_health_check.sql` - Good starting point; include in daily health reports
- `job_history.sql` - Check nightly job completion status

### Permissions Required
All standalone scripts are read-only. You need:
- **VIEW SERVER STATE** (for DMVs like sys.dm_os_wait_stats)
- **VIEW DEFINITION** (for some schema queries)
- Access to msdb for job-related queries

## Standalone Diagnostic Scripts Reference

| Script | Purpose | Best Used For |
|--------|---------|---------------|
| `quick_health_check.sql` | All-in-one health overview | Daily/weekly health checks |
| `blocking_chains.sql` | Visualize blocking issues | Incident response (during incidents) |
| `active_sessions.sql` | See what's running now | Performance troubleshooting |
| `tempdb_contention.sql` | Analyze TempDB usage | Capacity planning, optimization |
| `wait_stats.sql` | Identify wait bottlenecks | Performance tuning |
| `index_fragmentation.sql` | Identify defragmentation needs | Maintenance scheduling |
| `database_size.sql` | Space utilization report | Capacity planning |
| `job_history.sql` | Recent job execution status | Automation verification |
| `autogrowth_events.sql` | Track autogrowth patterns (TF1233) | Disk capacity analysis |

---
