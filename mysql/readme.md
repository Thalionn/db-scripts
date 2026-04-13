# MySQL Diagnostic Scripts

Scripts tested on MySQL 5.7 and 8.0.

## Sessions & Connections

| Script | Description |
|--------|-------------|
| `sessions.sql` | Current threads and connection states |
| `table_locks.sql` | Table lock contention analysis |

## Performance

| Script | Description |
|--------|-------------|
| `slow_queries.sql` | Slow query log analysis (24h window) |
| `innodb_status.sql` | InnoDB buffer pool and lock metrics |

## Replication

| Script | Description |
|--------|-------------|
| `replication_status.sql` | Replication lag and error monitoring |

## Storage

| Script | Description |
|--------|-------------|
| `disk_usage.sql` | Space consumption by database |

## Documentation

| Script | Description |
|--------|-------------|
| `duplicate_indexes.sql` | Duplicate index detection |
| `generate_documentation.sql` | Database documentation generator |

## Prerequisites

Performance schema must be enabled:

```sql
UPDATE mysql.global_variables 
SET VARIABLE_VALUE = 'ON'
WHERE VARIABLE_NAME = 'performance_schema';
```

Enable slow query log if needed:

```sql
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 2;
```

## Quick Test

```bash
mysql -e "SELECT * FROM information_schema.processlist;"
mysql < sessions.sql
```
