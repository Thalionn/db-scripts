-- ============================================================================
-- Script: generate_documentation.sql
-- Purpose: Generate database documentation in text/markdown format
-- Usage:   @generate_documentation.sql
-- Notes:   Run as DBA user
-- ============================================================================

SET LINESIZE 200
SET PAGESIZE 50000
COLUMN output FORMAT A5000

PROMPT ============================================================
PROMPT Database Documentation Report
PROMPT ============================================================
PROMPT Database: &DBNAME
PROMPT Generated: &SYSDATE
PROMPT ============================================================

PROMPT
PROMPT *** TABLES ***
PROMPT

SELECT 
    c.owner || '.' || c.table_name AS table_name,
    c.column_name,
    c.data_type ||
        CASE 
            WHEN c.data_type IN ('VARCHAR2','CHAR') THEN '(' || c.data_length || ')'
            WHEN c.data_type IN ('NUMBER') AND c.data_precision IS NOT NULL THEN '(' || c.data_precision || ',' || c.data_scale || ')'
            ELSE ''
        END AS data_type,
    CASE WHEN c.nullable = 'N' THEN 'NOT NULL' ELSE 'NULL' END AS nullable,
    c.data_default
FROM dba_tables t
JOIN dba_columns c ON t.owner = c.owner AND t.table_name = c.table_name
WHERE t.owner = USER
  AND t.tablespace_name NOT IN ('SYSTEM','SYSAUX')
ORDER BY t.table_name, c.column_id;

PROMPT
PROMPT *** VIEWS ***
PROMPT

SELECT owner || '.' || view_name AS view_name
FROM dba_views
WHERE owner = USER
ORDER BY view_name;

PROMPT
PROMPT *** INDEXES ***
PROMPT

SELECT 
    i.owner || '.' || i.table_name || '.' || i.index_name AS index_name,
    i.index_type,
    i.uniqueness,
    c.column_name,
    i.tablespace_name,
    (s.bytes / 1024) AS size_kb
FROM dba_indexes i
JOIN dba_ind_columns c ON i.owner = c.index_owner AND i.index_name = c.index_name
LEFT JOIN dba_segments s ON i.owner = s.owner AND i.index_name = s.segment_name
WHERE i.owner = USER
  AND i.tablespace_name NOT IN ('SYSTEM','SYSAUX')
ORDER BY i.table_name, c.column_position;

PROMPT
PROMPT *** PROCEDURES, FUNCTIONS, PACKAGES ***
PROMPT

SELECT 
    object_name,
    object_type,
    status,
    TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI') AS last_modified
FROM dba_objects
WHERE owner = USER
  AND object_type IN ('PROCEDURE','FUNCTION','PACKAGE','PACKAGE BODY')
ORDER BY object_type, object_name;

PROMPT
PROMPT *** SEQUENCES ***
PROMPT

SELECT 
    sequence_owner || '.' || sequence_name AS sequence_name,
    min_value,
    max_value,
    increment_by,
    last_number
FROM dba_sequences
WHERE sequence_owner = USER
ORDER BY sequence_name;

PROMPT
PROMPT *** CONSTRAINTS ***
PROMPT

SELECT 
    owner || '.' || table_name || '.' || constraint_name AS constraint_name,
    constraint_type,
    status,
    validated
FROM dba_constraints
WHERE owner = USER
  AND constraint_type IN ('P','R','U','C')
ORDER BY table_name, constraint_type;

SET PAGESIZE 100
