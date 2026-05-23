-- ============================================================================
-- Script: database_size.sql
-- Purpose: Database and file space consumption analysis
-- Usage:   Verify sufficient disk before large operations; capacity planning
-- Notes:   Includes data files, log files, and space utilization metrics
-- ============================================================================

SET NOCOUNT ON;

DECLARE @DatabaseName NVARCHAR(128) = DB_NAME();

SELECT TOP 50 
    ROW_NUMBER() OVER (ORDER BY mf.type, mf.name) AS row_num,
    @DatabaseName AS database_name,
    mf.Name AS logical_name,
    mf.type_desc AS file_type,
    CASE mf.type_desc 
        WHEN 'ROWS' THEN CAST(mf.size / 128.0 AS DECIMAL(18,2)) 
        ELSE CAST(mf.size / 128.0 * 35.076 AS DECIMAL(18,2)) END AS size_mb,
    CASE mf.type_desc 
        WHEN 'ROWS' THEN 
            ISNULL(CAST(FILEPROPERTY(mf.name, 'SpaceUsed') / 128.0 AS DECIMAL(18,2)), 0)
        ELSE NULL END AS used_mb,
    CASE mf.type_desc 
        WHEN 'ROWS' THEN 
            CAST(NULLIF((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')), 0) / 128.0 AS DECIMAL(18,2))
        ELSE CAST(NULLIF(mf.size, 0) * (35.076/128) AS DECIMAL(18,2)) END AS alloc_mb,
    CASE mf.type_desc 
        WHEN 'ROWS' THEN 
            ROUND(CAST((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS DECIMAL(5,2)) / NULLIF(mf.size / 128.0, 0) * 100, 2)
        ELSE NULL END AS utilization_pct,
    mf.physical_name,
    CASE 
        WHEN mf.max_size = -1 THEN 'UNLIMITED'
        WHEN mf.max_size = 0 THEN 'GROWTH ONLY'
        ELSE CAST(mf.max_size / 128.0 AS DECIMAL(10,2)) + ' MB' END AS max_size_status
FROM sys.master_files mf
WHERE mf.database_id = DB_ID()
ORDER BY 
    CASE WHEN mf.type_desc = 'LOG' THEN 0 ELSE 1 END,  
    mf.name;

PRINT '';
PRINT 'CAPACITY ALERT:';
PRINT '- Review large allocations with low utilization for potential shrinking';
PRINT '- Log file should be sized to 70-80% utilization for best performance';