-- ============================================================================
-- Script: tempdb_contention.sql
-- Purpose: Analyze TempDB contention and usage patterns  
-- Usage:   Run periodically to identify blocking/bottlenecks in TempDB
-- Notes:   Safe for production; read-only queries only
-- ============================================================================

SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

PRINT '';
PRINT '========================================';
PRINT 'TempDB Contention Analysis';  
PRINT '========================================';
PRINT '';

-- ============================================================================
-- SECTION 1: TempDB File Space Usage
-- ============================================================================
PRINT '--- SECTION 1: TempDB File Space ---';
PRINT '';

SELECT 
    f.name AS FileName,
    f.type_desc AS FileType,
    CAST(f.size / 128.0 AS DECIMAL(18,2)) AS TotalSizeMB,
    CAST(fu.allocated_extent_page_count * 8.0 / 1024.0 AS DECIMAL(18,2)) AS AllocatedMB,
    CAST(fu.unallocated_extent_page_count * 8.0 / 1024.0 AS DECIMAL(18,2)) AS UnallocatedMB,  
    CAST(uic.user_object_alloc_count AS BIGINT) AS UserObjectsPages,
    CAST(uic.system_object_alloc_count AS BIGINT) AS SystemObjectsPages,
    CAST(fu.mixed_extent_alloc_count AS INT) AS MixedAllocations,
    CASE 
        WHEN CAST(fu.allocated_extent_page_count * 100.0 / NULLIF(f.size, 0) AS DECIMAL(5,2)) < 70
            THEN 'OK'
        WHEN CAST(fu.allocated_extent_page_count * 100.0 / NULLIF(f.size, 0) AS DECIMAL(5,2)) < 85
            THEN 'MONITOR'
        ELSE 'FULL'
    END AS UsageStatus
FROM tempdb.sys.database_files f
JOIN tempdb.sys.dm_db_file_space_usage fu WITH (NOLOCK) ON f.file_id = fu.file_id
CROSS APPLY (
    SELECT 
        SUM(user_allocated_page_count) AS user_object_alloc_count, 
        SUM(system_allocated_page_count) AS system_object_alloc_count
    FROM tempdb.system.partition_stats
) uic;

PRINT '';

-- ============================================================================
-- SECTION 2: TempDB Spikes and Growth Events (Last 4 hours)  
-- ============================================================================
PRINT '--- SECTION 2: Recent Activity (Current Session) ---';
PRINT '';

SELECT TOP 50 
    session_id,
    login_name,
    host_process,
    status,
    command,
    wait_type,
    wait_time,
    t.text AS CommandText
FROM sys.dm_exec_requests r WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE session_id > 50
ORDER BY r.session_id;

PRINT '';

-- ============================================================================
-- SECTION 3: Locks and Deadlocks Involving TempDB
-- ============================================================================   
PRINT '--- SECTION 3: Active Locks in TempDB ---';
PRINT '';

SELECT TOP 20
    lt.resource_type,
    lt.request_mode,
    lt.granted_request_mode,
    lt.wait_duration_ms,
    l.resource_description,
    l.session_id,
    s.login_name,
    r.command,
    db_name(l.resource_database_id) AS resource_database
FROM sys.dm_db_fts_table_filters lf WITH (NOLOCK)
CROSS APPLY (SELECT * FROM tempdb.sys.dm_os_waiting_tasks lt WITH (NOLOCK)) wt WITH (NOLOCK)
CROSS APPLY sys.dm_exec_requests r WITH (NOLOCK)
LEFT JOIN tempdb.sys.dm_tran_locks l ON lt.resource_address = 0x -- Placeholder for tempDB locks

-- Alternative simpler approach if extended events show deadlocks:  
PRINT 'Note: TempDB deadlock graphs are stored in Extended Events file:';
PRINT '   CHECK path from sys.dm_xe_session_files for xevents where session_name=''deadlocks'''';

PRINT '';

-- ============================================================================
-- SECTION 4: Pinned In-Memory Objects (Buffer Pool Pressure)  
-- ============================================================================
PRINT '--- SECTION 4: Memory Grantees (TempDB Queries) ---';
PRINT '';

SELECT TOP 25
    session_id,
    login_name,
    memory_granted_kb / 1024.0 AS GrantedMemoryMB,
    r.command,
    LEFT(r.text, 80) AS CommandPreview
FROM sys.dm_exec_requests r WITH (NOLOCK)
LEFT JOIN sys.dm_exec_query_memory_grants mg WITH (NOLOCK) ON r.session_id = mg.session_id AND r.request_id = mg.request_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE session_id > 50 AND memory_granted_kb IS NOT NULL
ORDER BY memory_granted_kb DESC;

PRINT '';

-- ============================================================================
-- SECTION 5: Current Lockers in TempDB  
-- ============================================================================
PRINT '--- SECTION 5: Active Operations ---';
PRINT '';

SELECT TOP 25
    session_id,
    login_name,
    status,
    command,
    cpu_time,
    total_elapsed_time,
    logical_reads,
    writes,
    open_resultset_count,
    db_name(database_id) AS current_database,
    t.text
FROM tempdb.sys.dm_exec_requests r WITH (NOLOCK)
CROSS APPLY sys.dm_exec_sql_text(sql_handle) t  
WHERE transaction_is_read_committed_snapshot_off = 0
   OR session_id IN (SELECT blocked_session_id FROM tempdb.sys.dm_exec_requests WHERE blocking_session_id > 0)
ORDER BY total_elapsed_time DESC;

PRINT '';

-- ============================================================================
-- SECTION 6: Deadlock Summary (if trace flag 1224 was used previously)  
-- ============================================================================
PRINT '--- SECTION 6: Recent Wait Types ---';
PRINT '';

SELECT TOP 30
    wait_type,
    waiting_tasks_count,
    waitTime_ms,
    signal_wait_time_ms,
    ROUND(wait_time_ms * 100.0 / NULLIF(SUM(wait_time_ms) OVER(), 0), 2) AS PctOfTotalWait,
    CASE 
        WHEN wait_type LIKE 'PAGEIOLATCH%' THEN 'I/O'
        WHEN wait_type = 'CXPACKET' OR wait_type = 'CXPOOL' THEN 'PARALLELISM'
        WHEN wait_type LIKE 'SOS_%' THEN 'MEMORY/MANAGER'
        ELSE 'OTHER'
    END AS Category
FROM tempdb.sys.dm_os_wait_stats WITH (NOLOCK)
WHERE wait_time_ms > 0
ORDER BY wait_time_ms DESC;

PRINT '';

-- ============================================================================
-- SECTION 7: Recommendations  
-- ============================================================================
PRINT '';
PRINT '========================================';
PRINT 'TempDB Contention Recommendations';  
PRINT '========================================';
PRINT '';
PRINT '- Review pinned objects blocking queries (SECTION 4)';
PRINT '- Check for circular waits causing blocked sessions (SECTION 5)';
PRINT '- Monitor wait_stats for I/O bottleneck patterns';
PRINT '- Consider adding more file groups if mixed allocations are high';
PRINT '';
PRINT 'For deadlock analysis:';  
PRINT '- Enable trace flag 1224 temporarily to capture deadlock graphs';  
PRINT '- Or use Extended Events session ''deadlocks'' for non-intrusive capture';

-- ============================================================================
-- Helper Query: Deadlock Graph XML (if captured)  
-- ============================================================================
PRINT '';
PRINT 'Query to view deadlock graph from xevent file:';
PRINT '';  
PRINT 'DECLARE @XML XML;';
PRINT 'SELECT @XML = CAST((SELECT event_data.value('\''(../../data/text)'\'', '\''nvarchar(max)'\'') FROM [sys.fn_xe_file_target_read_file('\''%system_health.xml'\'', NULL, NULL, NULL)] FOR XML PATH('\''root'\'')) AS XML)';
PRINT 'SELECT @XML.query('\''//event[\''/@name='\''xml_deadlock_report'\'']/data/xml/\''@timestamp)' + '''';'');

PRINT '';
PRINT '========================================';
PRINT 'Analysis complete!';
PRINT '========================================';
