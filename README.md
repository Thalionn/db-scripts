# DBA Toolbelt

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.md)

A collection of SQL scripts for database administration across Oracle, PostgreSQL, MySQL, and SQL Server.

## What This Is

A personal toolbelt of diagnostic and maintenance scripts for day-to-day DBA work. Scripts are production-tested and organized by database platform. Includes both quick-reference scripts and a complete monitoring database for SQL Server.

## Supported Platforms

| Platform | Scripts | Status |
|----------|---------|--------|
| Oracle | 8 | Active |
| PostgreSQL | 8 | Active |
| MySQL | 6 | Active |
| SQL Server | 21 | Active |

## Quick Start

### Standalone Scripts

Each script runs independently - just open in your database client and execute.

**Oracle**
- `oracle/sessions_active.sql` - Current session inventory
- `oracle/tablespace_check.sql` - Tablespace utilization with alerts
- `oracle/blocking_sessions.sql` - Lock contention analysis

**PostgreSQL**
- `postgres/sessions_current.sql` - Active connections
- `postgres/locks_blocking.sql` - Lock wait chains
- `postgres/bloat_check.sql` - Table bloat detection

**MySQL**
- `mysql/sessions.sql` - Thread inventory
- `mysql/innodb_status.sql` - Buffer pool metrics
- `mysql/slow_queries.sql` - Query performance analysis

**SQL Server**
- `sqlserver/active_sessions.sql` - SPID inventory
- `sqlserver/wait_stats.sql` - Wait type statistics
- `sqlserver/blocking_chains.sql` - Blocking session tree

### SQL Server DBATools Database

A complete monitoring and maintenance database for SQL Server. Includes:

- Performance monitoring (waits, perf counters, query stats)
- Backup tracking
- Security auditing (login attempts, role changes)
- Index maintenance logging
- Alert framework
- Growth projections
- AG/replica health monitoring

**Installation:**

```bash
# Run scripts in order:
# 1. 00_create_database.sql
# 2. 01_tables.sql
# 3. 02_procedures.sql
# ... continue through 16_baseline_comparison.sql
```

See `sqlserver/dbatools/readme.md` for details.

## Prerequisites

- Oracle 11g+ (for Oracle scripts)
- PostgreSQL 12+ (for PostgreSQL scripts)
- MySQL 5.7+ (for MySQL scripts)
- SQL Server 2016+ (for SQL Server scripts)
- Appropriate database privileges (DBA role, sysadmin, etc.)

## License

MIT License - free to use, just credit the author.

---

*Author: Andrew Reischl | GitHub: https://github.com/Thalionn/db-scripts*
