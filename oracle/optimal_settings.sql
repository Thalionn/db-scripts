-- ============================================================================
-- Script: optimal_settings.sql
-- Purpose: Apply Oracle best practice settings
-- Usage:   @optimal_settings.sql (run as SYSDBA)
-- Notes:   Review each section before execution in production
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 5000
COLUMN name FORMAT A30
COLUMN value FORMAT A50

PROMPT ============================================================
PROMPT Oracle Optimal Configuration Script
PROMPT Based on community best practices
PROMPT ============================================================

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 1: Memory Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Current SGA Target:
SELECT name, value, unit FROM v$parameter WHERE name LIKE '%sga%';

PROMPT
PROMPT Current PGA Target:
SELECT name, value, unit FROM v$parameter WHERE name LIKE '%pga%';

PROMPT
PROMPT Memory Target:
SELECT name, value, unit FROM v$parameter WHERE name LIKE '%memory%';

PROMPT
PROMPT Recommended: Use Automatic Memory Management (AMM)
PROMPT ALTER SYSTEM SET memory_target = XG SCOPE=SPFILE;
PROMPT ALTER SYSTEM SET sga_target = YG SCOPE=SPFILE;
PROMPT ALTER SYSTEM SET pga_aggregate_target = ZG SCOPE=SPFILE;
PROMPT Where X = 75% of available RAM, Y = 60%, Z = 20%

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 2: Process and Session
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Current processes/sessions:
SELECT name, value FROM v$parameter WHERE name IN ('processes', 'sessions');

PROMPT
PROMPT Recommended: processes = 300 + (num users * 1.5)
PROMPT Example: ALTER SYSTEM SET processes = 300 SCOPE=SPFILE;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 3: UNDO and TEMP Tablespace
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Undo Tablespace:
SELECT tablespace_name, status, contents FROM dba_tablespaces 
WHERE contents = 'UNDO';

PROMPT
PROMPT Undo Retention:
SELECT name, value FROM v$parameter WHERE name = 'undo_retention';
PROMPT Recommended: 900 (15 min) for OLTP, higher for DW

PROMPT
PROMPT Temp Tablespace:
SELECT tablespace_name, status, contents FROM dba_tablespaces 
WHERE contents = 'TEMPORARY';

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 4: Optimizer Features
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Optimizer Mode:
SELECT name, value FROM v$parameter WHERE name = 'optimizer_mode';

PROMPT
PROMPT Adaptive Features (11g+):
SELECT name, value FROM v$parameter WHERE name LIKE '%adaptive%';

PROMPT
PROMPT Recommended: 
PROMPT ALTER SYSTEM SET optimizer_features_enable = '19.0.0' SCOPE=SPFILE;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 5: Trace File Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Diagnostic Destination:
SELECT name, value FROM v$parameter WHERE name = 'diagnostic_dest';

PROMPT
PROMPT Max Dump File Size:
SELECT name, value FROM v$parameter WHERE name = 'max_dump_file_size';

PROMPT
PROMPT Recommended: max_dump_file_size = unlimited (or large value)

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 6: Session/Cursor Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Cursor Settings:
SELECT name, value FROM v$parameter WHERE name LIKE 'open_cursors%';
SELECT name, value FROM v$parameter WHERE name LIKE 'session_cached%';

PROMPT
PROMPT Recommended:
PROMPT ALTER SYSTEM SET open_cursors = 300 SCOPE=BOTH;
PROMPT ALTER SYSTEM SET session_cached_cursors = 50 SCOPE=BOTH;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 7: Buffer Cache
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Buffer Pool Sizes (check current):
SELECT name, value, isdefault FROM v$parameter WHERE name LIKE 'db_cache_size%';

PROMPT
PROMPT Keep Pool (frequently accessed tables):
PROMPT ALTER SYSTEM SET db_keep_cache_size = XG SCOPE=SPFILE;

PROMPT
PROMPT Recycle Pool (large scan tables):
PROMPT ALTER SYSTEM SET db_recycle_cache_size = YG SCOPE=SPFILE;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 8: Redo Log Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Redo Log Groups:
SELECT group#, thread#, sequence#, bytes/1024/1024 AS size_mb, 
       members, status, first_change# FROM v$log ORDER BY group#;

PROMPT
PROMPT Redo Log Sizing Recommendations:
PROMPT - Size logs for 15-30 min of activity
PROMPT - Have 3+ groups per thread
PROMPT - Group members on different disks

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 9: Archive Log Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Archive Log Status:
SELECT name, value FROM v$parameter WHERE name LIKE '%archive%';

PROMPT
PROMPT Fast Recovery Area:
SELECT name, value FROM v$parameter WHERE name LIKE '%db_recovery_file_dest%';

PROMPT
PROMPT Recommended: FRA = 2x largest datafile + redo size

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 10: Resource Manager
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Resource Manager Status:
SELECT name, value FROM v$parameter WHERE name = 'resource_manager_plan';

PROMPT
PROMPT To enable:
PROMPT ALTER SYSTEM SET resource_manager_plan = 'DEFAULT_PLAN' SCOPE=BOTH;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 11: SQL Tuning
PROMPT ------------------------------------------------------------

PROMPT
PROMPT SQL Plan Management:
SELECT name, value FROM v$parameter WHERE name LIKE '%optimizer_%';

PROMPT
PROMPT Recommended:
PROMPT ALTER SYSTEM SET optimizer_capture_sql_plan_baselines = TRUE SCOPE=BOTH;
PROMPT ALTER SYSTEM SET optimizer_use_sql_plan_baselines = TRUE SCOPE=BOTH;

PROMPT
PROMPT ------------------------------------------------------------
PROMPT SECTION 12: Backup Settings
PROMPT ------------------------------------------------------------

PROMPT
PROMPT Control File Autobackup:
SELECT name, value FROM v$parameter WHERE name = 'control_file_record_keep_time';

PROMPT
PROMPT Recommended: control_file_record_keep_time = 14+ days

PROMPT
PROMPT ============================================================
PROMPT Settings to Configure Manually
PROMPT ============================================================

PROMPT
PROMPT 1. RMAN Retention Policy:
PROMPT    CONFIGURE RETENTION POLICY TO RECOVERY WINDOW OF 14 DAYS;

PROMPT
PROMPT 2. Flashback (if licensed):
PROMPT    ALTER DATABASE FLASHBACK ON;

PROMPT
PROMPT 3. Password File:
PROMPT    Ensure remote_login_passwordfile=EXCLUSIVE

PROMPT
PROMPT 4. AUDIT (for compliance):
PROMPT    AUDIT SELECT TABLE, INSERT TABLE, DELETE TABLE BY ACCESS;

PROMPT
PROMPT 5. Statistics Collection (automated):
PROMPT    EXEC DBMS_STATS.GATHER_SCHEMA_STATS(ESTIMATE_PERCENT=>10);

PROMPT
PROMPT ============================================================
PROMPT Configuration script complete
PROMPT Review recommendations before applying
PROMPT ============================================================
