-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- Oracle DBATools Scheduler Jobs
-- Run as DBATOOLS user with CREATE JOB privilege

-- Job: Capture wait stats every 15 minutes
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_CAPTURE_WAIT_STATS',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.capture_wait_stats; END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=15',
        enabled => TRUE,
        comments => 'Capture wait statistics every 15 minutes'
    );
END;
/

-- Job: Capture session snapshot every 5 minutes
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_CAPTURE_SESSION_SNAP',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.capture_session_snapshot; END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=5',
        enabled => TRUE,
        comments => 'Capture session snapshots every 5 minutes'
    );
END;
/

-- Job: Capture tablespace sizes hourly
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_CAPTURE_TABLESPACES',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.capture_tablespace_sizes; END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY',
        enabled => TRUE,
        comments => 'Capture tablespace sizes hourly'
    );
END;
/

-- Job: Capture SQL stats every 30 minutes
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_CAPTURE_SQL_STATS',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.capture_sql_stats; END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=MINUTELY;INTERVAL=30',
        enabled => TRUE,
        comments => 'Capture SQL performance stats every 30 minutes'
    );
END;
/

-- Job: Capture index stats weekly
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_CAPTURE_INDEX_STATS',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.capture_index_stats; END;',
        start_date => SYSTIMESTAMP + 1,
        repeat_interval => 'FREQ=WEEKLY',
        enabled => TRUE,
        comments => 'Capture index statistics weekly'
    );
END;
/

-- Job: Purge old data daily at 2 AM
BEGIN
    DBMS_SCHEDULER.CREATE_JOB (
        job_name => 'DBA_PURGE_OLD_DATA',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN dba.purge_old_data(p_days => 30); END;',
        start_date => SYSTIMESTAMP + 1,
        repeat_interval => 'FREQ=DAILY;BYHOUR=2',
        enabled => TRUE,
        comments => 'Purge data older than 30 days daily at 2 AM'
    );
END;
/

PROMPT Created 6 scheduler jobs for Oracle DBATools.
PROMPT Use dba_scheduler_jobs to view job status.
