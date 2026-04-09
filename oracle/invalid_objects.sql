-- ============================================================================
-- Script: invalid_objects.sql
-- Purpose: Find invalid objects requiring recompilation
-- Usage:   Run after major patches or upgrades
-- Notes:   Cross-check with dba_errors for specific errors
-- ============================================================================

SET LINESIZE 150 PAGESIZE 50
COLUMN owner FORMAT A20
COLUMN object_type FORMAT A20
COLUMN object_name FORMAT A40
COLUMN status FORMAT A10
COLUMN last_ddl FORMAT A20

SELECT 
    owner,
    object_type,
    object_name,
    status,
    TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS') AS last_ddl,
    object_id
FROM dba_objects
WHERE status != 'VALID'
  AND owner NOT IN ('SYS', 'SYSTEM', 'CTXSYS', 'ORDSYS')
  AND object_type IN ('PACKAGE', 'PACKAGE BODY', 'PROCEDURE', 'FUNCTION', 
                      'TRIGGER', 'VIEW', 'SYNONYM', 'MATERIALIZED VIEW')
ORDER BY owner, object_type, object_name;
