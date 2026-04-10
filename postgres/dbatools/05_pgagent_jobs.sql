-- ============================================================================
-- Script: 05_pgagent_jobs.sql
-- Purpose: Create pgAgent jobs for scheduled collection
-- Usage:   Run after 04_helper_functions.sql
-- Notes:   Requires pgAgent extension installed
-- ============================================================================

-- Create pgAgent extension if not exists
-- Note: Run as superuser: CREATE EXTENSION pgagent;

-- Job: DBATools - Capture Wait Stats (every 15 minutes)
INSERT INTO pgagent.pga_job (
    jobjclid, jobname, jobdesc, jobenabled, jobcreatedby, jobcreated, jobalteredby, jobaltered
)
SELECT 
    (SELECT clid FROM pgagent.pga_jobclass WHERE clname = 'DBATools'),
    'DBATools - Capture Wait Stats',
    'Collects wait statistics every 15 minutes',
    TRUE,
    current_user,
    NOW(),
    current_user,
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Wait Stats'
);

-- Add step to wait stats job
INSERT INTO pgagent.pga_jobstep (
    jstjobid, jstname, jstenabled, jstkind, jstonerror, jstcode, jstconnstr, jstdesc
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Wait Stats'),
    'Capture Wait Stats',
    TRUE,
    's', -- SQL
    'f', -- Fail
    'SELECT * FROM dba.capture_wait_stats();',
    '',
    'Capture wait statistics'
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_jobstep 
    WHERE jstjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Wait Stats')
      AND jstname = 'Capture Wait Stats'
);

-- Add schedule (every 15 minutes)
INSERT INTO pgagent.pga_schedule (
    jscjobid, jscname, jscenabled, jscstart, jscend, jscinterval
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Wait Stats'),
    'Every15Minutes',
    TRUE,
    '00:00:00'::TIME,
    '23:59:59'::TIME,
    '00:15:00'::INTERVAL
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_schedule 
    WHERE jscjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Wait Stats')
);

-- Job: DBATools - Capture Session Snapshot (every 5 minutes)
INSERT INTO pgagent.pga_job (
    jobjclid, jobname, jobdesc, jobenabled, jobcreatedby, jobcreated, jobalteredby, jobaltered
)
SELECT 
    (SELECT clid FROM pgagent.pga_jobclass WHERE clname = 'DBATools'),
    'DBATools - Capture Sessions',
    'Captures session snapshots every 5 minutes',
    TRUE,
    current_user,
    NOW(),
    current_user,
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Sessions'
);

INSERT INTO pgagent.pga_jobstep (
    jstjobid, jstname, jstenabled, jstkind, jstonerror, jstcode, jstdesc
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Sessions'),
    'Capture Sessions',
    TRUE,
    's',
    'f',
    'SELECT * FROM dba.capture_session_snapshot();',
    'Capture current sessions'
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_jobstep 
    WHERE jstjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Sessions')
);

INSERT INTO pgagent.pga_schedule (
    jscjobid, jscname, jscenabled, jscstart, jscend, jscinterval
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Sessions'),
    'Every5Minutes',
    TRUE,
    '00:00:00'::TIME,
    '23:59:59'::TIME,
    '00:05:00'::INTERVAL
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_schedule 
    WHERE jscjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Sessions')
);

-- Job: DBATools - Capture Database Sizes (hourly)
INSERT INTO pgagent.pga_job (
    jobjclid, jobname, jobdesc, jobenabled, jobcreatedby, jobcreated, jobalteredby, jobaltered
)
SELECT 
    (SELECT clid FROM pgagent.pga_jobclass WHERE clname = 'DBATools'),
    'DBATools - Capture Database Sizes',
    'Records database size metrics hourly',
    TRUE,
    current_user,
    NOW(),
    current_user,
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Database Sizes'
);

INSERT INTO pgagent.pga_jobstep (
    jstjobid, jstname, jstenabled, jstkind, jstonerror, jstcode, jstdesc
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Database Sizes'),
    'Capture Sizes',
    TRUE,
    's',
    'f',
    'SELECT * FROM dba.capture_database_sizes(); SELECT * FROM dba.capture_table_sizes();',
    'Capture database and table sizes'
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_jobstep 
    WHERE jstjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Database Sizes')
);

INSERT INTO pgagent.pga_schedule (
    jscjobid, jscname, jscenabled, jscstart, jscend, jscinterval
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Database Sizes'),
    'Hourly',
    TRUE,
    '00:00:00'::TIME,
    '23:59:59'::TIME,
    '01:00:00'::INTERVAL
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_schedule 
    WHERE jscjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Database Sizes')
);

-- Job: DBATools - Capture Query Stats (every 30 minutes)
INSERT INTO pgagent.pga_job (
    jobjclid, jobname, jobdesc, jobenabled, jobcreatedby, jobcreated, jobalteredby, jobaltered
)
SELECT 
    (SELECT clid FROM pgagent.pga_jobclass WHERE clname = 'DBATools'),
    'DBATools - Capture Query Stats',
    'Captures top queries by resource usage',
    TRUE,
    current_user,
    NOW(),
    current_user,
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Query Stats'
);

INSERT INTO pgagent.pga_jobstep (
    jstjobid, jstname, jstenabled, jstkind, jstonerror, jstcode, jstdesc
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Query Stats'),
    'Capture Query Stats',
    TRUE,
    's',
    'f',
    'SELECT * FROM dba.capture_query_stats(p_min_calls := 10);',
    'Capture query statistics'
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_jobstep 
    WHERE jstjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Query Stats')
);

INSERT INTO pgagent.pga_schedule (
    jscjobid, jscname, jscenabled, jscstart, jscend, jscinterval
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Query Stats'),
    'Every30Minutes',
    TRUE,
    '00:00:00'::TIME,
    '23:59:59'::TIME,
    '00:30:00'::INTERVAL
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_schedule 
    WHERE jscjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Capture Query Stats')
);

-- Job: DBATools - Purge Old Data (daily at midnight)
INSERT INTO pgagent.pga_job (
    jobjclid, jobname, jobdesc, jobenabled, jobcreatedby, jobcreated, jobalteredby, jobaltered
)
SELECT 
    (SELECT clid FROM pgagent.pga_jobclass WHERE clname = 'DBATools'),
    'DBATools - Purge Old Data',
    'Removes data older than retention period (30 days)',
    TRUE,
    current_user,
    NOW(),
    current_user,
    NOW()
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_job WHERE jobname = 'DBATools - Purge Old Data'
);

INSERT INTO pgagent.pga_jobstep (
    jstjobid, jstname, jstenabled, jstkind, jstonerror, jstcode, jstdesc
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Purge Old Data'),
    'Purge Data',
    TRUE,
    's',
    'f',
    'SELECT * FROM dba.purge_old_data(p_retention_days := 30);',
    'Purge old monitoring data'
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_jobstep 
    WHERE jstjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Purge Old Data')
);

INSERT INTO pgagent.pga_schedule (
    jscjobid, jscname, jscenabled, jscstart, jscend, jscminutes, jschours
)
SELECT 
    (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Purge Old Data'),
    'DailyMidnight',
    TRUE,
    '00:00:00'::TIME,
    '23:59:59'::TIME,
    ARRAY[0]::INTEGER[],
    ARRAY[0]::INTEGER[]
WHERE NOT EXISTS (
    SELECT 1 FROM pgagent.pga_schedule 
    WHERE jscjobid = (SELECT jobid FROM pgagent.pga_job WHERE jobname = 'DBATools - Purge Old Data')
);

-- Create job class if not exists
INSERT INTO pgagent.pga_jobclass (clname, clcreator, clcreated)
SELECT 'DBATools', current_user, NOW()
WHERE NOT EXISTS (SELECT 1 FROM pgagent.pga_jobclass WHERE clname = 'DBATools');

RAISE NOTICE 'pgAgent jobs created successfully.';
RAISE NOTICE 'Jobs created:';
RAISE NOTICE '  - DBATools - Capture Wait Stats (every 15 min)';
RAISE NOTICE '  - DBATools - Capture Sessions (every 5 min)';
RAISE NOTICE '  - DBATools - Capture Database Sizes (hourly)';
RAISE NOTICE '  - DBATools - Capture Query Stats (every 30 min)';
RAISE NOTICE '  - DBATools - Purge Old Data (daily midnight)';
