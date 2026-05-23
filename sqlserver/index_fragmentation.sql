-- ============================================================================
-- Script: index_fragmentation.sql
-- Purpose: Index fragmentation levels for maintenance planning
-- Usage:   Schedule reorganize (>5%) or rebuild (>30%) during off-hours
-- Notes:   'LIMITED' mode is faster; adjust to 'FULL' for detailed analysis
-- ============================================================================

SET NOCOUNT ON;

DECLARE @DatabaseName NVARCHAR(128) = DB_NAME();

SELECT TOP 100 
    @DatabaseName AS database_name,
    OBJECT_NAME(s.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    s.avg_fragmentation_in_percent,
    CASE s.page_count
        WHEN NULL THEN 'TINY (skipped)'
        ELSE CAST(s.page_count / 128.0 AS INT) + ' pages (~' +
            CAST(s.page_count * 8.0 / 1024.0 AS DECIMAL(10,1)) + 'KB)' END AS table_size_kb,
    s.avg_page_space_used_in_percent,
    CASE 
        WHEN s.avg_fragmentation_in_percent >= 30 THEN 'REBUILD'
        WHEN s.avg_fragmentation_in_percent BETWEEN 5 AND 29 THEN 'REORGANIZE'
        ELSE 'OK - No action needed'
    END AS recommended_action,
    s.record_count,
    CASE 
        WHEN s.record_count IS NULL THEN 'N/A'
        ELSE CAST(s.avg_fill_factor_act * 100 AS DECIMAL(5,2)) + '%'
    END AS fill_factor_actual
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED'
) s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 0
  AND (s.page_count IS NULL OR s.page_count > 1000)
  AND OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
ORDER BY s.avg_fragmentation_in_percent DESC;

PRINT '';
PRINT 'TOP FRAGMENTED INDEXES IDENTIFIED:';
PRINT '- Review recommended_action column for maintenance tasks';
PRINT '- Use sp_page Verify or DBCC SHOWCONTIG for detailed analysis';