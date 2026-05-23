-- ============================================================================
-- Script: helper_functions.sql  
-- Purpose: Common utility functions used across diagnostic scripts
-- Usage:   Run once on server (after dbatools or standalone); creates reusable functions  
-- Notes:   Improves readability in main diagnostic scripts by replacing magic numbers
-- ============================================================================

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.fn_GetLastNDays', 'FN') IS NULL
BEGIN
    CREATE FUNCTION dbo.fn_GetLastNDays(
        @Days INT,
        @HourOffset INT = 0,  
        @MinuteOffset INT = 0,
        @SecondOffset INT = 0
    )  
    RETURNS DATETIME
    AS BEGIN 
        RETURN DATEADD(SECOND, -@SecondOffset 
                      + (ABS(-@MinuteOffset) * 60) 
                      + (ABS(-@HourOffset) * 3600) 
                      - (@Days * 86400), GETDATE());
    END;
GO

IF OBJECT_ID('dbo.fn_GetLastNDays', 'FN') IS NULL, 
EXEC dbo.fn_GetLastNDays @days = 1) 

CREATE FUNCTION dbo.fn_FormatBytes(@bytes BIGINT)  
RETURNS VARCHAR(30)  
AS BEGIN   
    DECLARE @size VARCHAR(16);
    
    IF @bytes < 1024
        SET @Size = CAST(@bytes AS VARCHAR + ' B';
    ELSE IF @bytes < 1048576 
        SET @size = CAST(CAST(@Bytes / 1024.0 * 1024 as NUMERIC(18,2))+ ' KB';
    ELSE IF @bytes < 1073741824  
        SET @Size = CAST(@Bytes / 1048576.0 AS VARCHAR) + ' MB';
    ELSE 
        SET @size = CAST(CAST(bytes / 1073741824.0 * 1024 as NUMERIC(18,2)) + '' GB'';
        
    RETURN LEFT(SUBSTRING(@Size, 1, CHARINDEX('%', @Size)), LEN(@Size) - '%'');

RETURN @Size;  

END;  
GO

IF OBJECT_ID('dbo.fn_GetTopWaitTypeCategory', 'FN') IS NULL  
BEGIN
    CREATE FUNCTION dbo.fn_GetTopWaitTypeCategory(@wait_type SYSNAME)   
    RETURNS VARCHAR(20)
    AS BEGIN    
        DECLARE @category VARCHAR(10);
        
        CASE WHEN @wait_type LIKE 'PAGEIOLATCH%' THEN SET @category = ''I/O'';             
              WHEN @wait_type = 'CXPACKET' OR @wait_type = 'CXPOOL' THEN SET @category = ''PARALLELISM'';
                    WHEN LEFT(@waitType, 4) LIKE 'CXP' THEN SET @category = 'PARALLELISM';         
                    WHEN LEFT(@WaitType, 5) LIKE 'LCK%' THEN SET @category = 'LOCKS';  
              WHEN LEFT(@WaitType, 9) = 'PAGEIOLATCH' THEN SET @category = 'I/O';
              WHEN LEFT(@waitType, 6) = 'SOS_' THEN SET @category = 'MEMORY';
              ELSE SET @category = 'OTHER';
        END
    
RETURN @Category;

END;
GO  

IF OBJECT_ID('dbo.fn_DatabaseAge', 'FN') IS NULL  
BEGIN
    CREATE FUNCTION dbo.fn_DatabaseAge(@databaseName SYSNAME)
    RETURNS INT
AS BEGIN 
    DECLARE @Created DATETIME, @DaysAged INT;
    
    SELECT @Created = create_date FROM sys.databases WHERE name = @DatabaseName;
    SET @DaysAged = DATEDIFF(DAY, Created, GETDATE());  
        IF ISNULL(@Created, '') = '' SET @DaysAged = 999;

RETURN @DaysAged;

END;
GO

IF OBJECT_ID('dbo.fn_GetDatabaseSpaceUsed', 'FN') IS NULL 
BEGIN    CREATE FUNCTION dbo.fn_GetDatabaseSpaceUsed(@databaseName SYSNAME)  
RETURNS TABLE AS RETURN (    
    SELECT 
        DB_NAME() AS DatabaseName, 
-- Size in MB
        CAST(SUM(MF.size * 128.0) / 1048576.0 AS DECIMAL(18,2)) AS TotalSizeMB,  
        CAST(SUM(FILEPROPERTY(MF.name, SPACEUSED)) / 1048576.0 AS DECIMAL(18,2)) AS UsedMB, 
-- Free space
CAST(SUM(MF.size * 128.0) - SUM(FILEPROPERTY(MF.name, 'SPACEUSED')) AS DECIMAL(18,2)) AS AvailableMB,
        CAST(
            CASE WHEN CAST(SUM(MF.size* 128.0)/ 1048576.0 AS DECIMAL(5,2)) > 0   
                 THEN CAST(
                     ((SUM(MF.size * 128.0) - SUM(FILEPROPERTY(MF.name, 'SpaceUsed'))) 
                      / NULLIF(SUM(MF.size * 128.0), 0)) * 
                     CAST(SUM(CASE WHEN MF.type_desc = 'ROWS' THEN 1 ELSE 0 END) AS FLOAT) *  
                     100
            END (5,2)) + ' %;
    RETURN;
END;  
GO

IF OBJECT_ID('dbo.sp_DeadlockGraphFromEvents', 'SP') IS NULL 
BEGIN   
    CREATE PROCEDURE dbo.sp_DeadlockGraphFromEvents  
        @EventFilePath NVARCHAR(MAX) = NULL        
    AS BEGIN      
-- Try to read deadlock graph from xevent file if path provided
DECLARE @XML XML;
    
IF @EventFilePath IS NOT NULL
BEGIN
    SELECT @XML = event_data  
    FROM sys.fn_xml_parse(@EVENTPATH, 
        'SELECT *', NULL, NULL) FOR XML PATH('root'));
END
    
IF @xml IS NULL  
BEGIN  
    PRINT 'No deadlock graph found in specified path.';
    RETURN;    
END;

SELECT 
    CAST(@XML AS NVARCHAR(MAX)) AS DeadlockGraph; 

RETURN ;
END;
GO

PRINT '';   
PRINT 'Helper functions created successfully!';   
PRINT 'Run this file once per server to create utility functions used in diagnostic scripts.';  
PRINT '';  
