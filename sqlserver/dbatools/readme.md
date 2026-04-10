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
| `09_security_audit.sql` | Security audit tables and procedures |
| `09B_security_jobs.sql` | Security audit job schedule |
| `10_errorlog_parser.sql` | SQL error log parsing and archiving |
| `11_alert_framework.sql` | Alert configuration and checks |
| `11B_mail_setup.sql` | Database Mail configuration |
| `11C_alert_jobs.sql` | Alert check job schedules |
| `12_capacity_planning.sql` | Database growth projection |
| `13_tempdb_contention.sql` | TempDB latch contention monitoring |
| `14_ag_replica_health.sql` | Availability Group health monitoring |
| `15_index_recommendations.sql` | Missing/unused index analysis |
| `16_baseline_comparison.sql` | Performance baseline and comparison |

## What Gets Collected

### Performance Monitoring
- Wait statistics (15-minute intervals)
- Performance counters (5-minute intervals)
- Database size history (hourly)
- Query performance snapshots (30-minute intervals)
- TempDB contention (latch waits)
- AG/replica synchronization health

### Audit & Security
- All login attempts (successful and failed)
- Failed login tracking with IP and hostname
- Login frequency by user
- Server role membership changes
- Permission changes

### Maintenance Logging
- Index maintenance operations (rebuild/reorganize)
- Backup history
- Integrity check results
- Error log events

## Alerts

**IMPORTANT: Database Mail must be configured before alerts will work.**

```bash
# 1. Run mail setup first
11B_mail_setup.sql   # Modify SMTP settings

# 2. Test email delivery
EXEC msdb.dbo.sp_send_dbmail
    @profile_name = 'DBATools',
    @recipients = 'your@email.com',
    @subject = 'Test',
    @body = 'Test';

# 3. Enable alert jobs
11C_alert_jobs.sql
```

## Key Views

```sql
-- Current top waits
SELECT * FROM dba.vWaitStatsCurrent ORDER BY WaitTimeMs DESC;

-- Databases needing backups
SELECT * FROM dba.vBackupStatus WHERE BackupStatus != 'OK';

-- Failed login attempts
SELECT * FROM dba.vFailedLogins24Hours;

-- Query performance outliers
SELECT * FROM dba.vQueryPerformanceOutliers;

-- Growth projections
SELECT * FROM dba.vGrowthProjection;

-- AG health status
SELECT * FROM dba.vAGReplicaHealth;

-- Recent errors
SELECT * FROM dba.vRecentErrors;

-- Weekly summary report
EXEC dba.GenerateWeeklySummary;
```

## Weekly Maintenance Tasks

```sql
-- 1. Update baselines quarterly
EXEC dba.CaptureBaseline @DaysForBaseline = 30;

-- 2. Compare to baseline weekly
EXEC dba.CompareToBaseline;

-- 3. Capture growth projections
EXEC dba.CalculateGrowthProjection;

-- 4. Review index recommendations
SELECT * FROM dba.vIndexRecommendations;
```

## Prerequisites

- SQL Server 2016 or later
- msdb access for Agent job creation
- Sufficient disk space for logging database
- SMTP server for email alerts

## Notes

- Test in non-production first
- Adjust thresholds in procedures to match your environment
- Consider partitioning tables for large-scale deployments
- Schedule baseline updates quarterly

## Credit

Inspired by:
- Brent Ozar's First Aid Kit (https://www.brentozar.com/first-aid/)
- Ola Hallengren's Maintenance Solution (https://ola.hallengren.com)
