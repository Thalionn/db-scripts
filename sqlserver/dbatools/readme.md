# DBATools Database

A centralized SQL Server monitoring and maintenance database inspired by Brent Ozar's First Aid Kit and Ola Hallengren's maintenance solution.

## Installation Order

Run scripts in numerical order on each SQL Server instance:

| Script | Purpose |
|--------|---------|
| `00_create_database.sql` | Create DBATools database and schema |
| `01_tables.sql` | Create all logging and history tables |
| `02_procedures.sql` | Core stored procedures for data collection |
| `03_views.sql` | Utility views for quick diagnostics |
| `04_functions.sql` | Helper functions |
| `05_jobs.sql` | SQL Agent jobs for scheduled collection |
| `06_login_trigger.sql` | Server trigger for login auditing |
| `07_ola_backup_template.sql` | Ola Hallengren backup job template |
| `08_index_maintenance_job.sql` | Index maintenance job |

## What Gets Collected

### Performance Monitoring
- Wait statistics (15-minute intervals)
- Performance counters (5-minute intervals)
- Database size history (hourly)
- Query performance snapshots (30-minute intervals)

### Audit & Security
- All login attempts (successful and failed)
- Failed login tracking with IP and hostname
- Login frequency by user

### Maintenance Logging
- Index maintenance operations (rebuild/reorganize)
- Backup history
- Integrity check results

## Views for Quick Analysis

```sql
-- Current top waits
SELECT * FROM dba.vWaitStatsCurrent ORDER BY WaitTimeMs DESC;

-- Databases needing backups
SELECT * FROM dba.vBackupStatus WHERE BackupStatus != 'OK';

-- Failed login attempts
SELECT * FROM dba.vFailedLogins24Hours;

-- Query performance outliers
SELECT * FROM dba.vQueryPerformanceOutliers;

-- Server inventory overview
SELECT * FROM dba.vServerInventory;
```

## Maintenance

### Adjust Retention
```sql
EXEC dba.PurgeOldData @RetentionDays = 30; -- Default
```

### Change Collection Intervals
Edit schedules in SQL Server Agent or modify `05_jobs.sql`.

### Add Server to Inventory
```sql
INSERT INTO dba.ServerInventory (ServerName, Environment, Notes)
VALUES ('YourServerName', 'PROD', 'Primary application database');
```

## Prerequisites

- SQL Server 2016 or later
- msdb access for Agent job creation
- Sufficient disk space for logging database
- Drive D:\SQLBackups\ for backup jobs (or update paths)

## Notes

- Change `sa` password or use Windows auth for trigger
- Test in non-production first
- Adjust thresholds in procedures to match your environment
- Consider partitioning tables for large-scale deployments

## Credit

Inspired by:
- Brent Ozar's First Aid Kit (https://www.brentozar.com/first-aid/)
- Ola Hallengren's Maintenance Solution (https://ola.hallengren.com)
