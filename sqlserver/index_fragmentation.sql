-- ============================================================================
-- Script: index_fragmentation.sql
-- Purpose: Index fragmentation levels for maintenance planning
-- Usage:   Schedule reorganize (>5%) or rebuild (>30%)
-- Notes:   Run during off-hours; skip tiny indexes
-- ============================================================================

SET NOCOUNT ON;

SELECT 
    DB_NAME() AS database_name,
    OBJECT_NAME(s.object_id) AS table_name,
    i.name AS index_name,
    i.type_desc,
    s.avg_fragmentation_in_percent,
    s.page_count,
    s.avg_page_space_used_in_percent,
    CASE 
        WHEN s.avg_fragmentation_in_percent >= 30 THEN 'REBUILD'
        WHEN s.avg_fragmentation_in_percent >= 5 THEN 'REORGANIZE'
        ELSE 'OK'
    END AS recommended_action
FROM sys.dm_db_index_physical_stats(
    DB_ID(), NULL, NULL, NULL, 'LIMITED'
) s
JOIN sys.indexes i ON s.object_id = i.object_id AND s.index_id = i.index_id
WHERE s.avg_fragmentation_in_percent > 0
  AND s.page_count > 1000
  AND OBJECTPROPERTY(s.object_id, 'IsUserTable') = 1
ORDER BY s.avg_fragmentation_in_percent DESC;
