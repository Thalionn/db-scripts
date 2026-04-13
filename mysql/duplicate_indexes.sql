-- ============================================================================
-- Script: duplicate_indexes.sql
-- Purpose: Find duplicate/redundant indexes on the same table
-- Usage:   mysql < duplicate_indexes.sql
-- Notes:   Review carefully before dropping
-- ============================================================================

SELECT 
    t.TABLE_SCHEMA,
    t.TABLE_NAME,
    s.INDEX_NAME AS index1,
    s2.INDEX_NAME AS index2,
    s.COLUMN_NAME AS index1_cols,
    s2.COLUMN_NAME AS index2_cols,
    ROUND(ss.INDEX_LENGTH/1024) AS index1_size_kb,
    ROUND(ss2.INDEX_LENGTH/1024) AS index2_size_kb,
    CASE 
        WHEN s2.NON_UNIQUE = 0 THEN 'Keep (Unique)'
        ELSE 'Consider Dropping'
    END AS recommendation
FROM information_schema.STATISTICS s
JOIN information_schema.STATISTICS s2 ON s.TABLE_SCHEMA = s2.TABLE_SCHEMA 
                                      AND s.TABLE_NAME = s2.TABLE_NAME 
                                      AND s.INDEX_NAME < s2.INDEX_NAME
JOIN information_schema.TABLES t ON s.TABLE_SCHEMA = t.TABLE_SCHEMA AND s.TABLE_NAME = t.TABLE_NAME
JOIN information_schema.STATISTICS ss ON s.TABLE_SCHEMA = ss.TABLE_SCHEMA 
                                      AND s.TABLE_NAME = ss.TABLE_NAME 
                                      AND s.INDEX_NAME = ss.INDEX_NAME
JOIN information_schema.STATISTICS ss2 ON s2.TABLE_SCHEMA = ss2.TABLE_SCHEMA 
                                        AND s2.TABLE_NAME = ss2.TABLE_NAME 
                                        AND s2.INDEX_NAME = ss2.INDEX_NAME
WHERE s.SEQ_IN_POSITION = s2.SEQ_IN_POSITION
  AND s.COLUMN_NAME = s2.COLUMN_NAME
  AND s.NON_UNIQUE != 0
  AND s2.NON_UNIQUE != 0
  AND t.TABLE_SCHEMA NOT IN ('information_schema','mysql','performance_schema','sys')
ORDER BY t.TABLE_SCHEMA, t.TABLE_NAME, s.INDEX_NAME, s2.INDEX_NAME;
