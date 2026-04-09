-- Oracle: Find Blocking Locks
-- Usage: Identify and resolve blocking sessions

SELECT 
    l.session_id,
    l.locked_mode,
    l.oracle_username,
    l.os_user_name,
    o.object_name,
    o.object_type,
    s.serial#,
    s.status
FROM v$locked_object l
JOIN dba_objects o ON l.object_id = o.object_id
JOIN v$session s ON l.session_id = s.sid;