-- ============================================================================
-- Script: generate_documentation.sql
-- Purpose: Generate database documentation in markdown format
-- Usage:   SELECT * FROM generate_documentation('mydb');
-- Notes:   Run with psql -f for file output
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_documentation(p_database name DEFAULT current_database())
RETURNS TABLE(output TEXT) AS $$
DECLARE
    v_output TEXT := '';
    v_table_name TEXT;
    v_schema_name TEXT;
    
    cur_tables CURSOR FOR
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
          AND table_type = 'BASE TABLE'
        ORDER BY table_schema, table_name;
    
    cur_views CURSOR FOR
        SELECT table_schema, table_name 
        FROM information_schema.views 
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
        ORDER BY table_schema, table_name;
BEGIN
    v_output := '# Database Documentation: ' || p_database || E'\n';
    v_output := v_output || 'Generated: ' || CURRENT_TIMESTAMP::text || E'\n';
    v_output := v_output || E'\n' || REPLICATE('-', 60) || E'\n\n';
    
    v_output := v_output || '## Tables' || E'\n\n';
    
    OPEN cur_tables;
    LOOP
        FETCH cur_tables INTO v_schema_name, v_table_name;
        EXIT WHEN NOT FOUND;
        
        v_output := v_output || '### ' || v_schema_name || '.' || v_table_name || E'\n';
        v_output := v_output || '| Column | Type | Nullable | Default |' || E'\n';
        v_output := v_output || '|--------|------|----------|---------|' || E'\n';
        
        FOR col IN
            SELECT 
                column_name, 
                data_type,
                is_nullable,
                column_default,
                character_maximum_length,
                numeric_precision,
                numeric_scale
            FROM information_schema.columns
            WHERE table_schema = v_schema_name AND table_name = v_table_name
            ORDER BY ordinal_position
        LOOP
            v_output := v_output || '| ' || col.column_name || ' | ';
            
            IF col.character_maximum_length IS NOT NULL THEN
                v_output := v_output || col.data_type || '(' || col.character_maximum_length || ')';
            ELSIF col.numeric_precision IS NOT NULL THEN
                v_output := v_output || col.data_type || '(' || col.numeric_precision || ',' || col.numeric_scale || ')';
            ELSE
                v_output := v_output || col.data_type;
            END IF;
            
            v_output := v_output || ' | ' || col.is_nullable || ' | ';
            v_output := v_output || COALESCE(col.column_default::text, '') || ' |' || E'\n';
        END LOOP;
        
        v_output := v_output || E'\n';
    END LOOP;
    CLOSE cur_tables;
    
    v_output := v_output || '## Views' || E'\n\n';
    
    OPEN cur_views;
    LOOP
        FETCH cur_views INTO v_schema_name, v_table_name;
        EXIT WHEN NOT FOUND;
        
        v_output := v_output || '- ' || v_schema_name || '.' || v_table_name || E'\n';
    END LOOP;
    CLOSE cur_views;
    
    v_output := v_output || E'\n' || '## Indexes' || E'\n\n';
    
    FOR v_schema_name, v_table_name IN
        SELECT table_schema, table_name 
        FROM information_schema.tables 
        WHERE table_schema NOT IN ('pg_catalog', 'information_schema')
          AND table_type = 'BASE TABLE'
    LOOP
        FOR idx IN
            SELECT indexname, indexdef
            FROM pg_indexes
            WHERE schemaname = v_schema_name AND tablename = v_table_name
        LOOP
            v_output := v_output || '- **' || idx.indexname || '**: ' || idx.indexdef || E'\n';
        END LOOP;
    END LOOP;
    
    RETURN QUERY SELECT v_output;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION generate_documentation(name) IS 
'Generates database documentation in markdown format. Usage: SELECT * FROM generate_documentation(''mydb'');';
