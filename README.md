# DBA Toolbelt

A curated collection of diagnostic and maintenance scripts for database administration across Oracle, PostgreSQL, MySQL, and SQL Server.

## Overview

This repository contains practical scripts I use regularly for day-to-day DBA work. Each script is tested and refined based on real production experience.

### Supported Platforms

| Database   | Scripts | Status |
|------------|---------|--------|
| Oracle     | 12      | Active |
| PostgreSQL | 10      | Active |
| MySQL      | 8       | Active |
| SQL Server | 9       | Active |

## Quick Reference

### Oracle
- `oracle/sessions_active.sql` - Current session inventory
- `oracle/tablespace_check.sql` - Space utilization with alerts
- `oracle/blocking_sessions.sql` - Lock contention analysis
- `oracle/wait_events.sql` - Performance bottleneck identification
- `oracle/temp_usage.sql` - Temporary tablespace consumption
- `oracle/undo_usage.sql` - Undo segment monitoring
- `oracle/invalid_objects.sql` - Schema health check
- `oracle/fragmentation.sql` - Table/index fragmentation

### PostgreSQL
- `postgres/sessions_current.sql` - Active connection overview
- `postgres/locks_blocking.sql` - Lock wait chain analysis
- `postgres/bloat_check.sql` - Table/index bloat detection
- `postgres/cache_hit_ratio.sql` - Buffer cache efficiency
- `postgres/replication_lag.sql` - Streaming replication status
- `postgres/slow_queries.sql` - Top waiters and slow sessions
- `postgres/table_size.sql` - Storage consumption breakdown
- `postgres/index_usage.sql` - Unused/missing index analysis

### MySQL
- `mysql/sessions.sql` - Current threads and connections
- `mysql/innodb_status.sql` - InnoDB metrics snapshot
- `mysql/slow_queries.sql` - Query performance analysis
- `mysql/table_locks.sql` - Lock contention by table
- `mysql/replication_status.sql` - Master/slave health
- `mysql/disk_usage.sql` - Storage per database

### SQL Server
- `sqlserver/active_sessions.sql` - SPID inventory
- `sqlserver/wait_stats.sql` - Wait type aggregation
- `sqlserver/blocking_chains.sql` - Blocking session tree
- `sqlserver/index_fragmentation.sql` - Fragmentation levels
- `sqlserver/database_size.sql` - Space consumption
- `sqlserver/job_history.sql` - Recent job execution
- `sqlserver/autogrowth_events.sql` - Growth event audit

## Usage

Scripts can be run directly via your database's command-line client:

```bash
# Oracle
sqlplus / as sysdba @oracle/sessions_active.sql

# PostgreSQL
psql -f postgres/sessions_current.sql

# MySQL
mysql < mysql/sessions.sql

# SQL Server
sqlcmd -i sqlserver/active_sessions.sql
```

Or copy/paste into your preferred IDE or management tool.

## Notes

- Most scripts require appropriate privileges (DBA role, SELECT_CATALOG_ROLE, etc.)
- Results vary based on database version and configuration
- Adjust thresholds (alert levels, row limits) to match your environment
- Test in non-production first when modifying

## Maintenance

Scripts are reviewed and updated periodically. Last review: 2026-04-09

---
*Feel free to fork and customize for your environment.*
