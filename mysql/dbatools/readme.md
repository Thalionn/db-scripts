# MySQL DBATools

A centralized MySQL/MariaDB monitoring and maintenance system.

## Installation Order

Run scripts in sequence:

| Script | Purpose |
|--------|---------|
| `00_create_database.sql` | Create DBATools database |
| `01_tables.sql` | Create all logging tables |
| `02_procedures.sql` | Data capture procedures |
| `03_views.sql` | Diagnostic views |
| `04_events.sql` | Event scheduler jobs |

## Prerequisites

- MySQL 8.0+ or MariaDB 10.3+
- Performance schema enabled
- Event scheduler enabled

### Enable Required Features

```sql
-- Enable performance schema (if not enabled)
UPDATE mysql.global_variables SET VARIABLE_VALUE = 'ON' WHERE VARIABLE_NAME = 'performance_schema';

-- Enable slow query log (for slow query capture)
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
SET GLOBAL log_queries_not_using_indexes = 'ON';
```

## Installation

```bash
mysql -u root -p < 00_create_database.sql
mysql -u root -p dbatools < 01_tables.sql
# ... continue through 04_events.sql
```

## What Gets Collected

### Performance Monitoring
- Query statistics (15-minute intervals)
- Connection snapshots (5-minute intervals)
- Table sizes (hourly)
- Index statistics (daily)
- InnoDB metrics (15-minute intervals)
- Slow queries (hourly capture)

### Replication
- Replication status (5-minute intervals)

### Maintenance
- Data purging (30-day retention by default)

## Key Views

```sql
-- Top queries by execution time
SELECT * FROM v_top_queries;

-- Table sizes
SELECT * FROM v_table_sizes;

-- Large tables (>1GB)
SELECT * FROM v_large_tables;

-- Slow queries
SELECT * FROM v_slow_queries;

-- Replication lag
SELECT * FROM v_replication_lag;

-- Unused indexes
SELECT * FROM v_unused_indexes;

-- Database growth
SELECT * FROM v_database_growth;
```

## Manual Commands

```sql
-- Run collections manually
CALL capture_query_stats();
CALL capture_connection_stats();
CALL capture_table_sizes();
CALL capture_index_stats();
CALL capture_replication_status();
CALL capture_innodb_stats();

-- Purge old data
CALL purge_old_data(30);

-- View event status
SELECT * FROM information_schema.EVENTS WHERE EVENT_SCHEMA = 'dbatools';
```

## MariaDB Notes

The DBATools work with MariaDB with minor changes:
- Event scheduler syntax is the same
- Performance schema tables may differ slightly
- Use `mysql.general_log` instead of `mysql.slow_log` for MariaDB

## Notes

- Test in non-production first
- Adjust retention days as needed
- Monitor event scheduler execution
- Ensure slow_query_log is enabled for slow query capture
