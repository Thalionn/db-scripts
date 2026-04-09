-- ============================================================================
-- Script: database_size.sql
-- Purpose: Database and file space consumption
-- Usage:   Verify sufficient disk before large operations
-- Notes:   Includes log file for full picture
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    mf.name AS logical_name,
    mf.type_desc AS file_type,
    CAST(mf.size / 128.0 AS DECIMAL(10,2)) AS size_mb,
    CAST(FILEPROPERTY(mf.name, 'SpaceUsed') / 128.0 AS DECIMAL(10,2)) AS used_mb,
    CAST((mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 AS DECIMAL(10,2)) AS free_mb,
    CAST(
        (mf.size - FILEPROPERTY(mf.name, 'SpaceUsed')) / 128.0 / (mf.size / 128.0) * 100 
        AS DECIMAL(5,2)
    ) AS free_pct,
    mf.physical_name,
    mf.max_size
FROM sys.master_files mf
WHERE mf.database_id = DB_ID()
ORDER BY mf.type, mf.name;
