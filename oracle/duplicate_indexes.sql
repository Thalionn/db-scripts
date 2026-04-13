-- ============================================================================
-- Script: duplicate_indexes.sql
-- Purpose: Find duplicate or redundant indexes on the same table
-- Usage:   @duplicate_indexes.sql
-- Notes:   Review carefully before dropping - check foreign keys
-- ============================================================================

SET LINESIZE 200
COLUMN table_name FORMAT A40
COLUMN index1 FORMAT A40
COLUMN index2 FORMAT A40
COLUMN index1_cols FORMAT A60
COLUMN index2_cols FORMAT A60
COLUMN size_kb1 FORMAT 999999999
COLUMN size_kb2 FORMAT 999999999

PROMPT ============================================================
PROMPT Duplicate/Redundant Index Report
PROMPT ============================================================

SELECT 
    i1.table_owner || '.' || i1.table_name AS table_name,
    i1.index_name AS index1,
    i2.index_name AS index2,
    i1.column_name AS index1_cols,
    i2.column_name AS index2_cols,
    ROUND(NVL(s1.bytes,0)/1024) AS size_kb1,
    ROUND(NVL(s2.bytes,0)/1024) AS size_kb2,
    CASE 
        WHEN i2.index_type = 'FUNCTION-BASED NORMAL' THEN 'Keep (FBI)'
        WHEN i2.uniqueness = 'UNIQUE' THEN 'Keep (Unique)'
        ELSE 'Consider Dropping'
    END AS recommendation
FROM dba_ind_columns i1
JOIN dba_ind_columns i2 ON i1.table_owner = i2.table_owner 
                       AND i1.table_name = i2.table_name 
                       AND i1.index_name < i2.index_name
JOIN dba_indexes idx1 ON i1.index_owner = idx1.owner AND i1.index_name = idx1.index_name
JOIN dba_indexes idx2 ON i2.index_owner = idx2.owner AND i2.index_name = idx2.index_name
LEFT JOIN dba_segments s1 ON idx1.owner = s1.owner AND idx1.index_name = s1.segment_name
LEFT JOIN dba_segments s2 ON idx2.owner = s2.owner AND idx2.index_name = s2.segment_name
WHERE i1.column_position = i2.column_position
  AND i1.column_name = i2.column_name
  AND idx1.index_type != 'FUNCTION-BASED NORMAL'
  AND idx2.index_type != 'FUNCTION-BASED NORMAL'
  AND idx1.uniqueness != 'UNIQUE'
  AND idx2.uniqueness != 'UNIQUE'
ORDER BY i1.table_owner, i1.table_name, i1.index_name, i2.index_name;

PROMPT
PROMPT Note: Review each pair carefully before dropping an index.
PROMPT - Check if foreign keys reference the columns
PROMPT - Check if the index is used by any queries (AWR/ASH)
PROMPT - Consider keeping the index with better clustering factor
PROMPT - Test in non-production before dropping
