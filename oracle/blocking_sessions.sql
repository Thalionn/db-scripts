-- ============================================================================
-- Script: blocking_sessions.sql
-- Purpose: Identify blocking sessions and their wait chains
-- Usage:   Run when users report hangs or timeouts
-- Notes:   Serializes blocking tree from head blocker down
-- ============================================================================

SET LINESIZE 180 PAGESIZE 50
COLUMN blocker_sid FORMAT 99999
COLUMN blocker_serial FORMAT 99999
COLUMN blocker_status FORMAT A12
COLUMN waiter_sid FORMAT 99999
COLUMN waiter_status FORMAT A12
COLUMN wait_event FORMAT A30
COLUMN object_name FORMAT A30

SELECT 
    blocker.sid AS blocker_sid,
    blocker.serial# AS blocker_serial,
    blocker.username AS blocker_user,
    blocker.status AS blocker_status,
    blocker.program AS blocker_program,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.status AS waiter_status,
    w.event AS wait_event,
    w.seconds_in_wait,
    o.object_name,
    o.object_type
FROM v$session blocker
JOIN v$session w ON blocker.sid = (
    SELECT blocking_session 
    FROM v$session 
    WHERE sid = w.sid
)
LEFT JOIN v$locked_object l ON w.sid = l.session_id
LEFT JOIN dba_objects o ON l.object_id = o.object_id
WHERE blocker.username IS NOT NULL
ORDER BY blocker.sid, w.sid;
