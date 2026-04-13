-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

-- Oracle DBATools Schema Setup
-- Run as SYS or SYSTEM with DBA role

PROMPT Creating DBATools schema and objects...

-- Create tablespace for DBATools if not exists
-- Uncomment and modify for your environment:
-- CREATE TABLESPACE DBATOOLS DATAFILE '+DATA' SIZE 100M AUTOEXTEND ON NEXT 10M;

-- Create DBATools user/schema
-- Uncomment and run as SYS:
-- CREATE USER DBATOOLS IDENTIFIED BY "YourPassword" DEFAULT TABLESPACE USERS;
-- GRANT CONNECT, RESOURCE, SELECT ANY DICTIONARY TO DBATOOLS;
-- GRANT SELECT ON V_$SESSION TO DBATOOLS;
-- GRANT SELECT ON V_$SYSTEM_EVENT TO DBATOOLS;
-- GRANT SELECT ON V_$SQLAREA TO DBATOOLS;
-- GRANT SELECT ON V_$INSTANCE TO DBATOOLS;
-- GRANT SELECT ON V_$DATABASE TO DBATOOLS;
-- GRANT EXECUTE ON DBMS_SCHEDULER TO DBATOOLS;

PROMPT DBATools schema creation script complete.
PROMPT Next: Run 01_tables.sql
