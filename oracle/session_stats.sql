-- Oracle: Check Session & Connection Stats
-- Usage: Monitor active sessions and connection pools

SELECT 
    username,
    program,
    machine,
    status,
    COUNT(*) as session_count
FROM v$session
WHERE username IS NOT NULL
GROUP BY username, program, machine, status
ORDER BY session_count DESC;