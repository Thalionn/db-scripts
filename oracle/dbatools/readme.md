# Oracle DBATools

A centralized Oracle monitoring and maintenance system.

## Installation Order

Run scripts in sequence as DBATOOLS user (or SYS to create user):

| Script | Purpose |
|--------|---------|
| `00_create_schema.sql` | Create DBATOOLS user and schema |
| `01_tables.sql` | Create all logging tables |
| `02_procedures.sql` | Data capture procedures |
| `03_views.sql` | Diagnostic views |
| `04_jobs.sql` | Scheduler jobs for automation |

## Prerequisites

- Oracle 12c or later
- DBA role or equivalent privileges
- SELECT privileges on V$ views

### Grant Required Privileges (as SYS)

```sql
GRANT CONNECT, RESOURCE TO DBATOOLS IDENTIFIED BY "password";
GRANT SELECT ANY DICTIONARY TO DBATOOLS;
GRANT CREATE JOB TO DBATOOLS;
```

## Installation

```bash
sqlplus / as sysdba @00_create_schema.sql
sqlplus dbatools/password @01_tables.sql
# ... continue through 04_jobs.sql
```

## What Gets Collected

### Performance Monitoring
- Wait statistics (15-minute intervals)
- Session snapshots (5-minute intervals)
- SQL performance stats (30-minute intervals)
- Tablespace sizes (hourly)
- Index statistics (weekly)

### Maintenance
- Data purging (30-day retention by default)
- Automated collection scheduling

## Key Views

```sql
-- Current top waits
SELECT * FROM dba_v_current_waits;

-- Tablespace usage
SELECT * FROM dba_v_tablespace_usage;

-- Top SQL by elapsed time
SELECT * FROM dba_v_top_sql;

-- Blocking sessions
SELECT * FROM dba_v_blocking_sessions;

-- Invalid objects
SELECT * FROM dba_v_invalid_objects;

-- Tablespace growth history
SELECT * FROM dba_v_tablespace_history;
```

## Manual Commands

```sql
-- Run collections manually
EXEC dba.capture_wait_stats;
EXEC dba.capture_session_snapshot;
EXEC dba.capture_tablespace_sizes;
EXEC dba.capture_sql_stats;
EXEC dba.capture_index_stats;

-- Purge old data
EXEC dba.purge_old_data(p_days => 30);

-- View job status
SELECT job_name, enabled, run_count FROM user_scheduler_jobs;
```

## Notes

- Test in non-production first
- Adjust retention days as needed
- Monitor scheduler job execution
- Grant additional V$ privileges if needed for full diagnostics
