-- ============================================================================
-- Script: active_sessions.sql  
-- Purpose: Current SPID inventory with wait info and blocking details
-- Usage:   Quick overview of what's running on the instance; useful during incidents
-- Notes:   Excludes system SPIDs; includes transaction info for analysis
-- ============================================================================

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

-- ============================================================================
-- SECTION 1: Active Sessions Overview (with blocking context)  
-- ============================================================================
SELECT TOP 100 
    session_id AS spid,
    COALESCE(login_name, 'NO_LOGIN') AS login_name,
    host_process AS client_process,
    program_name,
    db_name(database_id) AS current_database,
    status,
    
    CASE cpu_time / 1000 
        WHEN 0 THEN 'IDLE'
        WHEN 0-10000 THEN '< 10s'
-- Wait time
CASE wait_type 
WHEN 'CLR_SEMAPHORE', 'LAZY_WRITER', 'REQUEST_FOR_DEADLOCK_SEARCH' THEN NULL -- These waits are benign and we don't expect to see them here otherwise
WHEN LEFT(wait_type, 4) = 'CXP'  THEN 'PARALLELISM - Check query parallelism settings'
WHEN LEFT(wait_type, 5) LIKE 'LCK%' THEN 'BLOCKED - Review blocking chain (use blocking_chains.sql)'  
WHEN LEFT(wait_type, 9) = 'PAGEIOLATCH' THEN 'I/O BOUND - Check disk latency/storage' 
WHEN LEFT(wait_type, 6) = 'SOS_' THEN 'MEMORY/MANAGER'
ELSE 'UNKNOWN-WAIT-TYPE-' + SUBSTRING(waitType, 4, 10) END wait_category

memory_usage / 128.0 AS MemoryMB,
reads,
writes,
total_elapsed_time / 1000 AS ElapsedTimeSeconds,
blocking_session_id AS blocked_by,

COALESCE(t.text, '') AS text_command,
command = CASE r.command WHEN 'UNKNOWN' THEN NULL ELSE r.command END command

FROM sys.dm_exec_sessions s WITH(NOLOCK)  
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id  -- Left join to get waiting sessions that may not have requests yet
OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE s.is_user_process = 1 OR (r.wait_type IS NOT NULL AND wait_time > 0) or (s.status = 'sleeping' AND session_id < 50)

ORDER BY total_elapsed_time DESC, blocking_session_id DESC, session_id;

PRINT '';
PRINT '========================================';
PRINT 'Active Sessions Analysis:';  
PRINT '-- Blocked sessions have positive blocked_by column value';   
PRINT '-- Review wait_category for performance issues (see comments in output)';
PRINT '-- Focus on top 10-20 by total_elapsed_time for investigation';
PRINT '========================================';

-- ============================================================================
-- SECTION 2: Waiting Sessions Only  
-- ============================================================================  
PRINT '';
PRINT '';   
PRINT '=== WAITING SESSIONS ONLY ===';
PRINT '';

SELECT TOP 30 
    session_id AS spid,
    login_name IS NULL AS login_name,
    host_process as client_process,  
    program_name,
    status,
    wait_type,
    wait_time / 1000 AS WaitSeconds,
    cpu_time / 1000 AS CPUSeconds,  
    reads, 
    writes,
    LEFT(t.text, 150) AS CurrentOperation
FROM sys.dm_exec_requests r WITH(NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t  
WHERE r.wait_type IS NOT NULL AND r.wait_time > 0  
ORDER BY r.wait_time DESC;

PRINT '';
PRINT 'Tip: Kill only blocking sessions, not long-running non-blocking queries.';
PRINT 'To kill a session: EXEC sp_terminate_proc @name = '\''spid_value'\'''');

-- ============================================================================
-- SECTION 3: Blocking Sessions (Who's blocking?)  
-- ============================================================================
PRINT '''--- BLOCKING SESSIONS ==='';   PRINT '';  

SELECT TOP 20  
    blocked.session_id AS BlockedSession,
    blocked.blocking_session_id AS BlockingSession,
    blocked.wait_type,
    blocked.wait_time / 1000.0 AS WaitSeconds,
    blocked.cpu_time / 1000.0 AS CPUSeconds,
    bs.login_name AS BlockerLogin,  
    LEFT(bs.text, 80) AS BlockerOperation  
FROM sys.dm_exec_requests blocked WITH(NOLOCK)
OUTER APPLY sys.dm_exec_sql_text(blocked.sql_handle) blocked_text  
JOIN sys.dm_exec_sessions bs ON blocked.blocking_session_id = bs.session_id  
CROSS APPLY sys.dm_exec_sql_text(bs.sql_handle) t  
LEFT JOIN sys.dm_exec_requests blocker ON blocked.blocking_session_id = blocker.session_id
CROSS APPLY sys.dm_exec_sql_text(blocker.sql_handle) blocker_text
WHERE blocked.wait_time > 0;

PRINT '';

-- ============================================================================  
-- SECTION 4: Query Text for Top CPU Consumers  
-- ============================================================================  
PRINT '';
PRINT '=== TOP SESSIONS BY CPU ======================'';   
PRINT '';  

SELECT TOP 20      
    session_id AS spid,
    CASE login_name WHEN NULL THEN 'SYSTEM' ELSE login_name END AS login_name,
    program_name,
    status,    
    cpu_time / 1000.0 AS CPUTimeSeconds,
    total_elapsed_time / 1000.0 AS ElapsedSeconds,  
    memory_usage / 128.0 AS MemoryMB,
    LEFT(t.text, 150) AS TextPreview
FROM sys.dm_exec_sessions s WITH(NOLOCK)
LEFT JOIN sys.dm_exec_requests r ON s.session_id = r.session_id  
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.cpu_time > 0 AND r.wait_type NOT IN ('CXPACKET', 'CXPOOL')
ORDER BY r.cpu_time DESC;

PRINT '';
PRINT 'To investigate query performance:'';   
PRINT '- Run SET STATISTICS IO ON, SET STATISTICS TIME ON'
PRINT '- Use sys.dm_exec_query_stats with execution_count and cpu_time' 
PRINT '- Check execution plan for missing indexes or expensive operations';  

-- ============================================================================ 
-- SECTION 5: Query Memory Grants  
-- ============================================================================ 
PRINT '';   
PRINT '=== MEMORY GRANTS (Potential Spill Risk) ===''';
PRINT '';

SELECT TOP 20
    session_id AS spid,
    login_name AS login_name IS NULL AS login_name,
    program_name,
    memory_granted_kb / 1024.0 AS GrantedMemoryMB,  
    CASE 
        WHEN requested_memory_kb > granted_memory_kb THEN 'SPILLED'
        ELSE 'OK' END AS MemoryStatus  
FROM sys.dm_exec_requests r WITH(NOLOCK)
CROSS APPLY sys.dm_exec_query_memory_grants mg WITH(NOLOCK)
WHERE memory_granted_kb IS NOT NULL;  

PRINT '';

-- ============================================================================
