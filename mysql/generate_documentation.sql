-- ============================================================================
-- Script: generate_documentation.sql
-- Purpose: Generate database documentation
-- Usage:   mysql < generate_documentation.sql
-- Notes:   Output to file for markdown formatting
-- ============================================================================

SELECT 
    CONCAT(
        '# Database Documentation: ', t.TABLE_SCHEMA, '\n\n',
        'Generated: ', NOW(), '\n\n',
        '---', '\n\n',
        '## Tables', '\n\n',
        '### ', t.TABLE_SCHEMA, '.', t.TABLE_NAME, '\n\n',
        '| Column | Type | Null | Default | Key |',
        '|--------|------|------|---------|-----|'
    ) AS output
FROM information_schema.TABLES t
WHERE t.TABLE_SCHEMA = DATABASE()
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('information_schema','mysql','performance_schema','sys');

SELECT 
    CONCAT(
        '| ', c.COLUMN_NAME, ' | ',
        c.COLUMN_TYPE, ' | ',
        c.IS_NULLABLE, ' | ',
        COALESCE(c.COLUMN_DEFAULT, ''), ' | ',
        c.COLUMN_KEY, ' |'
    ) AS column_def
FROM information_schema.COLUMNS c
JOIN information_schema.TABLES t ON c.TABLE_SCHEMA = t.TABLE_SCHEMA AND c.TABLE_NAME = t.TABLE_NAME
WHERE t.TABLE_SCHEMA = DATABASE()
  AND t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_SCHEMA NOT IN ('information_schema','mysql','performance_schema','sys')
ORDER BY t.TABLE_NAME, c.ORDINAL_POSITION;

SELECT CONCAT('\n## Views\n') AS output
UNION ALL
SELECT CONCAT('- ', v.TABLE_SCHEMA, '.', v.VIEW_NAME)
FROM information_schema.VIEWS v
WHERE v.TABLE_SCHEMA = DATABASE()
  AND v.TABLE_SCHEMA NOT IN ('information_schema','mysql','performance_schema','sys')
ORDER BY 1;

SELECT CONCAT('\n## Indexes\n') AS output
UNION ALL
SELECT CONCAT('- **', s.INDEX_NAME, '** on ', s.TABLE_NAME, ': ', s.INDEX_DEF)
FROM information_schema.STATISTICS s
WHERE s.TABLE_SCHEMA = DATABASE()
  AND s.TABLE_SCHEMA NOT IN ('information_schema','mysql','performance_schema','sys')
ORDER BY s.TABLE_NAME, s.INDEX_NAME;
