-- ============================================================================
-- Copyright (c) 2026 Andrew Reischl. All rights reserved.
-- Author:  Andrew Reischl
-- GitHub:  https://github.com/Thalionn/db-scripts
-- License: MIT License - Free to use, just credit the author.
-- ============================================================================

USE DBATools;
GO

CREATE OR ALTER PROCEDURE dba.GenerateHTMLHealthReport
    @DatabaseName NVARCHAR(128) = NULL,
    @OutputDatabaseName NVARCHAR(128) = 'DBATools',
    @OutputTableName NVARCHAR(256) = 'HTMLReports'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HTML NVARCHAR(MAX);
    DECLARE @ServerName NVARCHAR(128) = @@SERVERNAME;
    DECLARE @ReportDate NVARCHAR(50) = CAST(GETDATE() AS VARCHAR);
    DECLARE @DBName NVARCHAR(128) = COALESCE(@DatabaseName, DB_NAME());

    SET @HTML = N'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Database Health Report - ' + @ServerName + '</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: ''Segoe UI'', Tahoma, Geneva, Verdana, sans-serif; background: #f5f5f5; padding: 20px; }
        .container { max-width: 1400px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: linear-gradient(135deg, #2196F3 0%, #1976D2 100%); color: white; padding: 30px; border-radius: 8px 8px 0 0; }
        .header h1 { font-size: 28px; margin-bottom: 10px; }
        .header .meta { opacity: 0.9; font-size: 14px; }
        .nav { background: #1565C0; padding: 10px 30px; display: flex; gap: 20px; overflow-x: auto; }
        .nav a { color: white; text-decoration: none; padding: 8px 16px; border-radius: 4px; transition: background 0.2s; white-space: nowrap; }
        .nav a:hover { background: rgba(255,255,255,0.15); }
        .content { padding: 30px; }
        .section { margin-bottom: 40px; }
        .section h2 { font-size: 20px; color: #333; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 2px solid #2196F3; }
        .section h3 { font-size: 16px; color: #666; margin: 20px 0 10px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 20px; font-size: 13px; }
        th { background: #f5f5f5; text-align: left; padding: 12px; font-weight: 600; color: #333; border-bottom: 2px solid #ddd; }
        td { padding: 10px 12px; border-bottom: 1px solid #eee; }
        tr:hover { background: #fafafa; }
        .status-ok { color: #4CAF50; font-weight: 600; }
        .status-warning { color: #FF9800; font-weight: 600; }
        .status-critical { color: #F44336; font-weight: 600; }
        .metric-card { display: inline-block; background: #f9f9f9; padding: 20px 30px; border-radius: 8px; margin: 10px 20px 10px 0; min-width: 150px; }
        .metric-card .value { font-size: 32px; font-weight: 700; color: #2196F3; }
        .metric-card .label { font-size: 12px; color: #666; text-transform: uppercase; margin-top: 5px; }
        .alert-box { padding: 15px 20px; border-radius: 4px; margin: 10px 0; }
        .alert-warning { background: #FFF3E0; border-left: 4px solid #FF9800; }
        .alert-critical { background: #FFEBEE; border-left: 4px solid #F44336; }
        .alert-info { background: #E3F2FD; border-left: 4px solid #2196F3; }
        .footer { text-align: center; padding: 20px; color: #999; font-size: 12px; border-top: 1px solid #eee; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Database Health Report</h1>
            <div class="meta">
                <strong>Server:</strong> ' + @ServerName + ' | 
                <strong>Database:</strong> ' + @DBName + ' | 
                <strong>Generated:</strong> ' + @ReportDate + '
            </div>
        </div>
        <div class="nav">
            <a href="#overview">Overview</a>
            <a href="#database">Database Status</a>
            <a href="#backups">Backup Status</a>
            <a href="#performance">Performance</a>
            <a href="#storage">Storage</a>
            <a href="#security">Security</a>
        </div>
        <div class="content">
            <div class="section" id="overview">
                <h2>System Overview</h2>
                <div class="metric-card">
                    <div class="value">' + CAST((SELECT COUNT(*) FROM sys.databases WHERE state = 0) AS VARCHAR) + '</div>
                    <div class="label">Databases</div>
                </div>
                <div class="metric-card">
                    <div class="value">' + CAST((SELECT COUNT(*) FROM sys.dm_exec_sessions WHERE status = 'running') AS VARCHAR) + '</div>
                    <div class="label">Active Sessions</div>
                </div>
                <div class="metric-card">
                    <div class="value">' + CAST((SELECT COUNT(*) FROM sys.dm_exec_requests WHERE blocking_session_id > 0) AS VARCHAR) + '</div>
                    <div class="label">Blocked Requests</div>
                </div>
                <div class="metric-card">
                    <div class="value">' + CAST((SELECT COUNT(*) FROM msdb.dbo.backupset WHERE backup_start_date > DATEADD(DAY, -1, GETDATE())) AS VARCHAR) + '</div>
                    <div class="label">Backups (24h)</div>
                </div>
            </div>
            
            <div class="section" id="database">
                <h2>Database Status</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Database</th>
                            <th>Status</th>
                            <th>Recovery Model</th>
                            <th>Size (MB)</th>
                            <th>Last Backup</th>
                        </tr>
                    </thead>
                    <tbody>';

    SELECT @HTML = @HTML + N'
                        <tr>
                            <td>' + name + '</td>
                            <td class="status-' + CASE WHEN state_desc = 'ONLINE' THEN 'ok' ELSE 'critical' END + '">' + state_desc + '</td>
                            <td>' + recovery_model_desc + '</td>
                            <td>' + CAST(CAST(physical_size * 8 / 1024 AS BIGINT) AS VARCHAR) + '</td>
                            <td>' + ISNULL((SELECT TOP 1 CAST(backup_finish_date AS VARCHAR) FROM msdb.dbo.backupset b WHERE b.database_name = d.name ORDER BY backup_finish_date DESC), 'NEVER') + '</td>
                        </tr>'
    FROM sys.databases d
    WHERE name NOT IN ('tempdb')
    ORDER BY name;

    SET @HTML = @HTML + N'
                    </tbody>
                </table>
            </div>
            
            <div class="section" id="backups">
                <h2>Backup Status</h2>';

    DECLARE @Overdue INT = (SELECT COUNT(*) FROM (
        SELECT d.name, MAX(b.backup_finish_date) AS last_backup
        FROM sys.databases d
        LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name AND b.type = 'D'
        WHERE d.name NOT IN ('tempdb')
        GROUP BY d.name
        HAVING MAX(b.backup_finish_date) IS NULL OR DATEDIFF(HOUR, MAX(b.backup_finish_date), GETDATE()) > 24
    ) x);

    IF @Overdue > 0
    BEGIN
        SET @HTML = @HTML + N'
                <div class="alert-box alert-warning">
                    <strong>Warning:</strong> ' + CAST(@Overdue AS VARCHAR) + ' database(s) missing recent backups (over 24 hours)
                </div>
                <table>
                    <thead>
                        <tr>
                            <th>Database</th>
                            <th>Last Backup</th>
                            <th>Hours Ago</th>
                            <th>Status</th>
                        </tr>
                    </thead>
                    <tbody>';
        
        SELECT @HTML = @HTML + N'
                        <tr>
                            <td>' + DatabaseName + '</td>
                            <td>' + ISNULL(CAST(LastFullBackup AS VARCHAR), 'NEVER') + '</td>
                            <td>' + CAST(HoursSinceBackup AS VARCHAR) + '</td>
                            <td class="status-' + CASE WHEN BackupStatus = 'OK' THEN 'ok' ELSE 'critical' END + '">' + BackupStatus + '</td>
                        </tr>'
        FROM (
            SELECT 
                d.name AS DatabaseName,
                MAX(b.backup_finish_date) AS LastFullBackup,
                DATEDIFF(HOUR, MAX(b.backup_finish_date), GETDATE()) AS HoursSinceBackup,
                CASE 
                    WHEN MAX(b.backup_finish_date) IS NULL THEN 'NO BACKUP'
                    WHEN DATEDIFF(HOUR, MAX(b.backup_finish_date), GETDATE()) > 24 THEN 'OVERDUE'
                    ELSE 'OK'
                END AS BackupStatus
            FROM sys.databases d
            LEFT JOIN msdb.dbo.backupset b ON d.name = b.database_name AND b.type = 'D'
            WHERE d.name NOT IN ('tempdb')
            GROUP BY d.name
        ) x
        WHERE BackupStatus != 'OK';

        SET @HTML = @HTML + N'
                    </tbody>
                </table>';
    END
    ELSE
    BEGIN
        SET @HTML = @HTML + N'
                <div class="alert-box alert-info">
                    <strong>All backups are current.</strong>
                </div>';
    END

    SET @HTML = @HTML + N'
            </div>
            
            <div class="section" id="performance">
                <h2>Top Waits</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Wait Type</th>
                            <th>Wait Count</th>
                            <th>Wait Time (ms)</th>
                            <th>Percentage</th>
                        </tr>
                    </thead>
                    <tbody>';

    SELECT @HTML = @HTML + N'
                        <tr>
                            <td>' + wait_type + '</td>
                            <td>' + CAST(waiting_task_count AS VARCHAR) + '</td>
                            <td>' + CAST(wait_time_ms AS VARCHAR) + '</td>
                            <td>' + CAST(CAST(wait_time_ms * 100.0 / NULLIF(SUM(wait_time_ms) OVER(), 0) AS DECIMAL(5,2)) AS VARCHAR) + '%</td>
                        </tr>'
    FROM sys.dm_os_wait_stats
    WHERE wait_time_ms > 0
      AND wait_type NOT IN ('CLR_SEMAPHORE', 'LAZY_WRITER', 'RESOURCE_QUEUE', 'SLEEP_TASK', 'SLEEP_SYSTEMTASK')
    ORDER BY wait_time_ms DESC;

    SET @HTML = @HTML + N'
                    </tbody>
                </table>
            </div>
            
            <div class="section" id="storage">
                <h2>Storage Usage</h2>
                <table>
                    <thead>
                        <tr>
                            <th>Database</th>
                            <th>Data Size (MB)</th>
                            <th>Log Size (MB)</th>
                            <th>Total Size (MB)</th>
                            <th>Usage %</th>
                        </tr>
                    </thead>
                    <tbody>';

    SELECT @HTML = @HTML + N'
                        <tr>
                            <td>' + DB_NAME + '</td>
                            <td>' + CAST(CAST(data_size_kb / 1024 AS BIGINT) AS VARCHAR) + '</td>
                            <td>' + CAST(CAST(log_size_kb / 1024 AS BIGINT) AS VARCHAR) + '</td>
                            <td>' + CAST(CAST((data_size_kb + log_size_kb) / 1024 AS BIGINT) AS VARCHAR) + '</td>
                            <td>' + CAST(CAST(used_space_pct AS DECIMAL(5,2)) AS VARCHAR) + '%</td>
                        </tr>'
    FROM (
        SELECT 
            DB_NAME() AS DB_Name,
            SUM(CASE WHEN type = 0 THEN size END) / 128 AS data_size_kb,
            SUM(CASE WHEN type = 1 THEN size END) / 128 AS log_size_kb,
            0 AS used_space_pct
        FROM sys.master_files
        WHERE database_id = DB_ID()
        GROUP BY database_id
    ) x;

    SET @HTML = @HTML + N'
                    </tbody>
                </table>
            </div>
            
            <div class="footer">
                <p>Generated by DBATools | Report Date: ' + @ReportDate + '</p>
                <p>For questions or issues, contact your database administrator</p>
            </div>
        </div>
    </div>
</body>
</html>';

    PRINT @HTML;

    IF @OutputDatabaseName IS NOT NULL AND @OutputTableName IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = @OutputTableName AND schema_id = SCHEMA_ID('dba'))
        BEGIN
            EXEC('CREATE TABLE ' + @OutputDatabaseName + '.dba.' + @OutputTableName + ' (ReportID BIGINT IDENTITY, ServerName NVARCHAR(128), ReportDate DATETIME, HTMLReport NVARCHAR(MAX))');
        END

        EXEC('INSERT INTO ' + @OutputDatabaseName + '.dba.' + @OutputTableName + ' (ServerName, ReportDate, HTMLReport) VALUES (@ServerName, GETDATE(), @HTML)', @HTML = @HTML);
    END
END
GO

PRINT 'HTML Health Report generator created.';
PRINT 'Usage: EXEC dba.GenerateHTMLHealthReport;';
PRINT 'Or: EXEC dba.GenerateHTMLHealthReport @DatabaseName = ''YourDB'', @OutputDatabaseName = ''DBATools'', @OutputTableName = ''HTMLReports'';';
