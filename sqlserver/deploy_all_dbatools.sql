-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================
-- Master Deployment Script for DBATools
-- Runs all scripts in correct order with proper error handling
-- ============================================================================

PRINT '========================================';
PRINT 'DBATools Master Deployment Script';
PRINT '========================================';
PRINT '';
GO

-- Set error handling
SET NOCOUNT ON;
GO

-- =============================================
-- SECTION 1: Create Database
-- =============================================
PRINT '--- Running 00_create_database.sql ---';

:r .\00_create_database.sql
GO

-- =============================================
-- SECTION 2: Create Tables
-- =============================================
PRINT '--- Running 01_tables.sql ---';

:r .\01_tables.sql
GO

-- =============================================
-- SECTION 3: Create Procedures
-- =============================================
PRINT '--- Running 02_procedures.sql ---';

:r .\02_procedures.sql
GO

-- =============================================
-- SECTION 4: Create Views
-- =============================================
PRINT '--- Running 03_views.sql ---';

:r .\03_views.sql
GO

-- =============================================
-- SECTION 5: Create Functions
-- =============================================
PRINT '--- Running 04_functions.sql ---';

:r .\04_functions.sql
GO

-- =============================================
-- SECTION 6: Create Jobs (with existence checks)
-- =============================================
PRINT '--- Running 05_jobs.sql ---';

-- Check if procedures exist before creating jobs
IF NOT EXISTS (SELECT 1 FROM sys.procedures WHERE name = 'CaptureWaitStats' AND schema_id = SCHEMA_ID('dba'))
BEGIN
    RAISERROR('Procedure dba.CaptureWaitStats does not exist. Run 02_procedures.sql first.', 16, 1);
END
ELSE
BEGIN
    :r .\05_jobs.sql
END
GO

-- =============================================
-- SECTION 7: Security Audit (Tables and Procedures)
-- =============================================
PRINT '--- Running 09_security_audit.sql ---';

:r .\09_security_audit.sql
GO

-- =============================================
-- SECTION 8: Security Jobs (skipping 06_login_trigger)
-- =============================================
PRINT '--- Running 09B_security_jobs.sql ---';

:r .\09B_security_jobs.sql
GO

-- =============================================
-- SECTION 9: Error Log Parser
-- =============================================
PRINT '--- Running 10_errorlog_parser.sql ---';

:r .\10_errorlog_parser.sql
GO

-- =============================================
-- SECTION 10: Alert Framework
-- =============================================
PRINT '--- Running 11_alert_framework.sql ---';

:r .\11_alert_framework.sql
GO

-- =============================================
-- SECTION 11: Alert Jobs
-- =============================================
PRINT '--- Running 11C_alert_jobs.sql ---';

:r .\11C_alert_jobs.sql
GO

-- =============================================
-- SECTION 12: Capacity Planning
-- =============================================
PRINT '--- Running 12_capacity_planning.sql ---';

:r .\12_capacity_planning.sql
GO

-- =============================================
-- SECTION 13: TempDB Contention (Fixed)
-- =============================================
PRINT '--- Running 13_tempdb_contention.sql ---';

:r .\13_tempdb_contention.sql
GO

-- =============================================
-- SECTION 14: AG Replica Health (Fixed)
-- =============================================
PRINT '--- Running 14_ag_replica_health.sql ---';

:r .\14_ag_replica_health.sql
GO

-- =============================================
-- SECTION 15: Index Recommendations
-- =============================================
PRINT '--- Running 15_index_recommendations.sql ---';

:r .\15_index_recommendations.sql
GO

-- =============================================
-- SECTION 16: Baseline Comparison
-- =============================================
PRINT '--- Running 16_baseline_comparison.sql ---';

:r .\16_baseline_comparison.sql
GO

-- =============================================
-- SECTION 17: Documentation
-- =============================================
PRINT '--- Running 17_documentation.sql ---';

:r .\17_documentation.sql
GO

-- =============================================
-- SECTION 18: Duplicate Indexes
-- =============================================
PRINT '--- Running 18_duplicate_indexes.sql ---';

:r .\18_duplicate_indexes.sql
GO

-- =============================================
-- SECTION 19: Login Transfer
-- =============================================
PRINT '--- Running 19_login_transfer.sql ---';

:r .\19_login_transfer.sql
GO

-- =============================================
-- SECTION 20: HTML Report (Fixed)
-- =============================================
PRINT '--- Running 20_html_report.sql ---';

:r .\20_html_report.sql
GO

-- =============================================
-- SKIP: Login Trigger (06_login_trigger.sql)
-- Reason: Causes login issues, needs manual deployment
-- =============================================
PRINT '--- SKIPPING 06_login_trigger.sql ---';
PRINT '    (Deploy manually after verifying trigger code)';
GO

-- =============================================
-- SKIP: Ola Backup Template (07_ola_backup_template.sql)
-- Reason: Requires Ola Hallengren solution installed first
-- =============================================
PRINT '--- SKIPPING 07_ola_backup_template.sql ---';
PRINT '    (Requires Ola Hallengren Maintenance Solution)';
GO

-- =============================================
-- SKIP: Index Maintenance Job (08_index_maintenance_job.sql)
-- Reason: Requires Ola Hallengren solution
-- =============================================
PRINT '--- SKIPPING 08_index_maintenance_job.sql ---';
PRINT '    (Requires Ola Hallengren Maintenance Solution)';
GO

-- =============================================
-- SKIP: Mail Setup (11B_mail_setup.sql)
-- Reason: Requires SMTP server configuration
-- =============================================
PRINT '--- SKIPPING 11B_mail_setup.sql ---';
PRINT '    (Requires SMTP server configuration)';
GO

-- =============================================
-- DEPLOYMENT COMPLETE
-- =============================================
PRINT '';
PRINT '========================================';
PRINT 'Deployment Complete!';
PRINT '========================================';
PRINT '';
PRINT 'Deployed successfully:';
PRINT '  - 00_create_database.sql';
PRINT '  - 01_tables.sql';
PRINT '  - 02_procedures.sql';
PRINT '  - 03_views.sql';
PRINT '  - 04_functions.sql';
PRINT '  - 05_jobs.sql';
PRINT '  - 09_security_audit.sql';
PRINT '  - 09B_security_jobs.sql';
PRINT '  - 10_errorlog_parser.sql';
PRINT '  - 11_alert_framework.sql';
PRINT '  - 11C_alert_jobs.sql';
PRINT '  - 12_capacity_planning.sql';
PRINT '  - 13_tempdb_contention.sql';
PRINT '  - 14_ag_replica_health.sql';
PRINT '  - 15_index_recommendations.sql';
PRINT '  - 16_baseline_comparison.sql';
PRINT '  - 17_documentation.sql';
PRINT '  - 18_duplicate_indexes.sql';
PRINT '  - 19_login_transfer.sql';
PRINT '  - 20_html_report.sql';
PRINT '';
PRINT 'Skipped (deploy manually):';
PRINT '  - 06_login_trigger.sql (login trigger)';
PRINT '  - 07_ola_backup_template.sql (requires Ola Hallengren)';
PRINT '  - 08_index_maintenance_job.sql (requires Ola Hallengren)';
PRINT '  - 11B_mail_setup.sql (requires SMTP config)';
PRINT '';
GO
