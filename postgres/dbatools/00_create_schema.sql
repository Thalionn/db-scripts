-- ============================================================================
-- Script: 00_create_schema.sql
-- Purpose: Create DBATools schema and extensions
-- Usage:   Run as superuser on each PostgreSQL instance
-- Notes:   Requires pg_stat_statements extension enabled
-- ============================================================================

-- Create extension for query statistics (if not exists)
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create DBATools schema
CREATE SCHEMA IF NOT EXISTS dba;

-- Grant permissions (adjust as needed for your environment)
GRANT USAGE ON SCHEMA dba TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA dba TO PUBLIC;

COMMENT ON SCHEMA dba IS 'DBATools monitoring schema for PostgreSQL';
