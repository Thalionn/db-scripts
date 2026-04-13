-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE TABLE dba.DatabaseDocumentation (
    DocID BIGINT IDENTITY(1,1) PRIMARY KEY,
    ServerName NVARCHAR(128),
    DatabaseName NVARCHAR(128),
    CaptureTime DATETIME DEFAULT GETDATE(),
    ObjectType NVARCHAR(50),
    SchemaName NVARCHAR(128),
    ObjectName NVARCHAR(256),
    ColumnName NVARCHAR(256),
    DataType NVARCHAR(128),
    MaxLength INT,
    Precision INT,
    Scale INT,
    IsNullable BIT,
    IsPrimaryKey BIT,
    IsForeignKey BIT,
    IsIdentity BIT,
    DefaultValue NVARCHAR(MAX),
    Description NVARCHAR(MAX),
    INDEX IX_Doc_Capture NONCLUSTERED (CaptureTime, DatabaseName, ObjectType)
);
GO

CREATE OR ALTER PROCEDURE dba.CaptureDatabaseDocumentation
    @ServerName NVARCHAR(128) = @@SERVERNAME,
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName NVARCHAR(128);
    DECLARE @SQL NVARCHAR(MAX);
    DECLARE @CapTime DATETIME = GETDATE();

    IF @DatabaseName IS NOT NULL
    BEGIN
        SET @DBName = @DatabaseName;
    END
    ELSE
    BEGIN
        SET @DBName = DB_NAME();
    END;

    SET @SQL = N'
    USE [' + @DBName + N'];

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName,
        ColumnName, DataType, MaxLength, Precision, Scale,
        IsNullable, IsPrimaryKey, IsForeignKey, IsIdentity
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''TABLE'',
        s.name,
        t.name,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
    FROM sys.tables t
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    WHERE t.is_ms_shipped = 0;

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName,
        ColumnName, DataType, MaxLength, Precision, Scale,
        IsNullable, IsPrimaryKey, IsForeignKey, IsIdentity
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''VIEW'',
        s.name,
        v.name,
        NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
    FROM sys.views v
    JOIN sys.schemas s ON v.schema_id = s.schema_id
    WHERE v.is_ms_shipped = 0;

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName,
        ColumnName, DataType, MaxLength, Precision, Scale,
        IsNullable, IsPrimaryKey, IsForeignKey, IsIdentity, DefaultValue
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''COLUMN'',
        s.name,
        t.name,
        c.name,
        ty.name,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        CASE WHEN ic.column_id IS NOT NULL THEN 1 ELSE 0 END,
        CASE WHEN fkc.parent_column_id IS NOT NULL THEN 1 ELSE 0 END,
        COLUMNPROPERTY(t.object_id, c.name, ''IsIdentity''),
        dc.definition
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    JOIN sys.tables t ON c.object_id = t.object_id
    JOIN sys.schemas s ON t.schema_id = s.schema_id
    LEFT JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
    LEFT JOIN sys.foreign_key_columns fkc ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
    WHERE t.is_ms_shipped = 0;

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName,
        ColumnName, DataType, MaxLength, Precision, Scale,
        IsNullable, IsPrimaryKey, IsForeignKey, IsIdentity
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''VIEW_COLUMN'',
        s.name,
        v.name,
        c.name,
        ty.name,
        c.max_length,
        c.precision,
        c.scale,
        c.is_nullable,
        CASE WHEN ic.column_id IS NOT NULL THEN 1 ELSE 0 END,
        0,
        COLUMNPROPERTY(v.object_id, c.name, ''IsIdentity'')
    FROM sys.columns c
    JOIN sys.types ty ON c.user_type_id = ty.user_type_id
    JOIN sys.views v ON c.object_id = v.object_id
    JOIN sys.schemas s ON v.schema_id = s.schema_id
    LEFT JOIN sys.identity_columns ic ON c.object_id = ic.object_id AND c.column_id = ic.column_id
    WHERE v.is_ms_shipped = 0;

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''PROCEDURE'',
        s.name,
        p.name
    FROM sys.procedures p
    JOIN sys.schemas s ON p.schema_id = s.schema_id
    WHERE p.is_ms_shipped = 0;

    INSERT INTO DBATools.dba.DatabaseDocumentation (
        ServerName, DatabaseName, CaptureTime,
        ObjectType, SchemaName, ObjectName
    )
    SELECT 
        @ServerName,
        @DBName,
        @CapTime,
        ''FUNCTION'',
        s.name,
        f.name
    FROM sys.objects f
    JOIN sys.schemas s ON f.schema_id = s.schema_id
    WHERE f.type IN (''FN'', ''IF'', ''TF'', ''AF'')
      AND f.is_ms_shipped = 0;
    ';

    EXEC sp_executesql @SQL, 
        N'@ServerName NVARCHAR(128), @DBName NVARCHAR(128), @CapTime DATETIME',
        @ServerName = @ServerName, @DBName = @DBName, @CapTime = @CapTime;

    SELECT @DBName AS DatabaseName, @CapTime AS CaptureTime, @@ROWCOUNT AS RowsInserted;
END
GO

CREATE OR ALTER PROCEDURE dba.GenerateDocumentation
    @DatabaseName NVARCHAR(128) = NULL,
    @OutputType NVARCHAR(20) = 'TEXT'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName NVARCHAR(128) = COALESCE(@DatabaseName, DB_NAME());
    DECLARE @Output NVARCHAR(MAX);

    SET @Output = '# Database Documentation: ' + @DBName + CHAR(13) + CHAR(10);
    SET @Output = @Output + 'Generated: ' + CAST(GETDATE() AS VARCHAR) + CHAR(13) + CHAR(10);
    SET @Output = @Output + REPLICATE('-', 50) + CHAR(13) + CHAR(10) + CHAR(13) + CHAR(10);

    PRINT @Output;

    DECLARE @TableName NVARCHAR(256);
    DECLARE @SchemaName NVARCHAR(128);
    DECLARE table_cursor CURSOR FOR
    SELECT DISTINCT SchemaName, ObjectName
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName
      AND ObjectType = 'TABLE'
    ORDER BY SchemaName, ObjectName;

    OPEN table_cursor;
    FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        PRINT '## ' + @SchemaName + '.' + @TableName;
        PRINT '';

        SELECT 
            ColumnName + 
            ' (' + DataType + 
            CASE WHEN MaxLength > 0 THEN '(' + CAST(MaxLength AS VARCHAR) + ')' ELSE '' END +
            CASE WHEN IsPrimaryKey = 1 THEN ' PK' ELSE '' END +
            CASE WHEN IsForeignKey = 1 THEN ' FK' ELSE '' END +
            CASE WHEN IsNullable = 0 THEN ' NOT NULL' ELSE '' END +
            CASE WHEN IsIdentity = 1 THEN ' IDENTITY' ELSE '' END +
            CASE WHEN DefaultValue IS NOT NULL THEN ' DEFAULT ' + DefaultValue ELSE '' END +
            ')'
        FROM dba.DatabaseDocumentation
        WHERE DatabaseName = @DBName
          AND ObjectType = 'COLUMN'
          AND SchemaName = @SchemaName
          AND ObjectName = @TableName
        ORDER BY ColumnName;

        PRINT '';

        FETCH NEXT FROM table_cursor INTO @SchemaName, @TableName;
    END

    CLOSE table_cursor;
    DEALLOCATE table_cursor;

    SET @Output = CHAR(13) + CHAR(10) + '---' + CHAR(13) + CHAR(10);
    SET @Output = @Output + '## Stored Procedures' + CHAR(13) + CHAR(10);
    PRINT @Output;

    SELECT SchemaName + '.' + ObjectName AS ProcedureName
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName AND ObjectType = 'PROCEDURE'
    ORDER BY SchemaName, ObjectName;

    SET @Output = CHAR(13) + CHAR(10) + '## Functions' + CHAR(13) + CHAR(10);
    PRINT @Output;

    SELECT SchemaName + '.' + ObjectName AS FunctionName
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName AND ObjectType = 'FUNCTION'
    ORDER BY SchemaName, ObjectName;
END
GO

CREATE OR ALTER PROCEDURE dba.GenerateQuickReference
    @DatabaseName NVARCHAR(128) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @DBName NVARCHAR(128) = COALESCE(@DatabaseName, DB_NAME());

    SELECT 
        SchemaName + '.' + ObjectName AS TableName,
        COUNT(*) AS ColumnCount
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName AND ObjectType = 'COLUMN'
    GROUP BY SchemaName, ObjectName
    ORDER BY SchemaName, ObjectName;

    SELECT 
        SchemaName + '.' + ObjectName AS ProcedureName
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName AND ObjectType = 'PROCEDURE'
    ORDER BY SchemaName, ObjectName;

    SELECT 
        SchemaName + '.' + ObjectName AS FunctionName
    FROM dba.DatabaseDocumentation
    WHERE DatabaseName = @DBName AND ObjectType = 'FUNCTION'
    ORDER BY SchemaName, ObjectName;
END
GO

PRINT 'Documentation capture procedure created.';
PRINT 'Usage:';
PRINT '  EXEC dba.CaptureDatabaseDocumentation @DatabaseName = ''YourDB'';';
PRINT '  EXEC dba.GenerateDocumentation @DatabaseName = ''YourDB'';';
PRINT '  EXEC dba.GenerateQuickReference @DatabaseName = ''YourDB'';';
