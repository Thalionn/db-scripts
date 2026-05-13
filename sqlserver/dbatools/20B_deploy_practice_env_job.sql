USE msdb;
GO

-- Create category if it does not exist (may not be deployed yet on target server)
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syscategories WHERE name = 'DBATools' AND category_class = 1)
    EXEC msdb.dbo.sp_add_category @class = 'JOB', @type = 'LOCAL', @name = 'DBATools';
GO

-- Job: DBATools - Deploy Practice Environment
IF EXISTS (SELECT job_id FROM msdb.dbo.sysjobs WHERE name = 'DBATools - Deploy Practice Environment')
    EXEC msdb.dbo.sp_delete_job @job_name = 'DBATools - Deploy Practice Environment', @delete_unused_schedule = 1;
GO

EXEC msdb.dbo.sp_add_job
    @job_name = 'DBATools - Deploy Practice Environment',
    @description = 'Downloads and deploys practice databases, scripts, and tools for lab/training environments',
    @category_name = 'DBATools',
    @enabled = 0;
GO

-- =============================================
-- Step 1: Download all resources from GitHub
-- =============================================
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Deploy Practice Environment',
    @step_name = 'Download Resources',
    @subsystem = 'PowerShell',
    @command = N'
$ErrorActionPreference = "Stop"
$OutputPath = "C:\DBATools\PracticeEnvironment"
$logDir = Join-Path $OutputPath "Logs"
$dateStr = Get-Date -Format yyyyMMdd
$logFile = Join-Path $logDir "deploy_$dateStr.log"

New-Item -ItemType Directory -Path $logDir -Force | Out-Null
$startMsg = "===== Step 1: Download Started: " + (Get-Date -Format "yyyy-MM-dd HH:mm:ss") + " ====="
$startMsg | Out-File -FilePath $logFile -Encoding UTF8

function Write-Log {
    param([string]$Message, [string]$ForegroundColor = "Gray")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Add-Content -Path $logFile -Encoding UTF8
    Write-Host $Message -ForegroundColor $ForegroundColor
}

Write-Log "========================================"
Write-Log "Downloading Practice Environment Resources"
Write-Log "========================================"

New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

function Download-RepoZip {
    param([string]$RepoUrl, [string]$DestPath, [string]$RepoName)
    if (Test-Path $DestPath) { Write-Log "  $RepoName already exists, skipped" -ForegroundColor Gray; return }
    $zipFile = $DestPath + ".zip"
    try {
        Write-Log "  Downloading $RepoName..." -ForegroundColor Green
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 120
        $tempDir = $DestPath + "_tmp"
        Expand-Archive -Path $zipFile -DestinationPath $tempDir -Force
        $extracted = Get-ChildItem -Path $tempDir -Directory | Select-Object -First 1
        if ($extracted) {
            Move-Item $extracted.FullName $DestPath
        } else {
            New-Item -ItemType Directory -Path $DestPath -Force | Out-Null
            Move-Item ($tempDir + "\*") $DestPath
        }
        Remove-Item $tempDir -Force -Recurse -ErrorAction SilentlyContinue
        Remove-Item $zipFile -Force
        Write-Log "  Downloaded: $RepoName" -ForegroundColor Green
    } catch {
        Write-Log ("  Failed to download " + $RepoName + ": " + $_) -ForegroundColor Yellow
    }
}

Write-Log "`n[1/3] Downloading db-scripts..." -ForegroundColor Cyan
$dbScriptsPath = Join-Path $OutputPath "db-scripts"
Download-RepoZip -RepoUrl "https://github.com/Thalionn/db-scripts/archive/refs/heads/main.zip" -DestPath $dbScriptsPath -RepoName "db-scripts"
if (-not (Test-Path (Join-Path $dbScriptsPath "sqlserver"))) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "db-scripts*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $dbScriptsPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName $dbScriptsPath.Split("\")[-1]
    }
}

Write-Log "`n[2/3] Downloading First Responder Kit..." -ForegroundColor Cyan
$frkPath = Join-Path $OutputPath "SQL-Server-First-Responder-Kit-main"
Download-RepoZip -RepoUrl "https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/archive/refs/heads/main.zip" -DestPath $frkPath -RepoName "First Responder Kit"
if (-not (Test-Path (Join-Path $frkPath "sp_Blitz.sql"))) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "SQL-Server-First-Responder-Kit*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $frkPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName ("SQL-Server-First-Responder-Kit-main")
    }
}

Write-Log "`n[3/3] Downloading Ola Hallengren Maintenance Solution..." -ForegroundColor Cyan
$olaPath = Join-Path $OutputPath "sql-server-maintenance-solution-master"
Download-RepoZip -RepoUrl "https://github.com/olahallengren/sql-server-maintenance-solution/archive/refs/heads/master.zip" -DestPath $olaPath -RepoName "Maintenance Solution"
if (-not (Get-ChildItem -Path $olaPath -Filter "*.sql" -ErrorAction SilentlyContinue)) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "sql-server-maintenance-solution*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $olaPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName ("sql-server-maintenance-solution-master")
    }
}

Write-Log "`nDownload complete!" -ForegroundColor Green
',
    @database_name = 'master',
    @on_success_action = 3,
    @on_fail_action = 2;
GO

-- =============================================
-- Step 2: Deploy practice environment via xp_cmdshell + sqlcmd
-- Uses xp_cmdshell to invoke sqlcmd on the downloaded script file
-- to avoid inlining the entire practice_environment_setup.sql (699 lines with GO batches).
-- xp_cmdshell is enabled temporarily and disabled after deployment.
-- =============================================
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Deploy Practice Environment',
    @step_name = 'Deploy Practice Database and Jobs',
    @subsystem = 'TSQL',
    @command = N'
PRINT ''=== Deploying Practice Database and Jobs ==='';

DECLARE @sqlcmd NVARCHAR(500), @cmd NVARCHAR(4000);
DECLARE @output TABLE (line NVARCHAR(4000));
DECLARE @logDir NVARCHAR(500) = N''C:\DBATools\PracticeEnvironment\Logs'';
DECLARE @logFile NVARCHAR(500) = @logDir + N''\deploy_'' + CONVERT(NVARCHAR(8), GETDATE(), 112) + N''.log'';
DECLARE @ts NVARCHAR(20);
DECLARE @echoCmd NVARCHAR(1000);

-- Enable xp_cmdshell first (needed for logging and deployment)
PRINT ''  Enabling xp_cmdshell...'';
EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1;
RECONFIGURE;

-- Create Logs directory
SET @echoCmd = N''if not exist "'' + @logDir + N''" mkdir "'' + @logDir + N''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;

-- Log start
SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] [Step 2] Deploying practice environment... >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;

-- Locate sqlcmd.exe using xp_fileexist
DECLARE @exists INT;
SET @sqlcmd = N''C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SQLCMD.EXE'';
EXEC master.dbo.xp_fileexist @sqlcmd, @exists OUTPUT;
IF @exists = 0
BEGIN
    SET @sqlcmd = N''C:\Program Files\Microsoft SQL Server\150\Tools\Binn\SQLCMD.EXE'';
    EXEC master.dbo.xp_fileexist @sqlcmd, @exists OUTPUT;
END
IF @exists = 0
BEGIN
    SET @sqlcmd = N''C:\Program Files\Microsoft SQL Server\140\Tools\Binn\SQLCMD.EXE'';
    EXEC master.dbo.xp_fileexist @sqlcmd, @exists OUTPUT;
END
IF @exists = 0
BEGIN
    SET @sqlcmd = N''C:\Program Files\Microsoft SQL Server\130\Tools\Binn\SQLCMD.EXE'';
    EXEC master.dbo.xp_fileexist @sqlcmd, @exists OUTPUT;
END
IF @exists = 0
    SET @sqlcmd = N''sqlcmd.exe'';

PRINT ''  Using sqlcmd: '' + @sqlcmd;
SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] [Step 2] Using sqlcmd: '' + @sqlcmd + '' >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;

-- Deploy practice_environment_setup.sql
SET @cmd = @sqlcmd + '' -S "(local)" -E -C -d master -i "C:\DBATools\PracticeEnvironment\db-scripts\sqlserver\practice_environment_setup.sql" -b'';
PRINT ''  Running: practice_environment_setup.sql'';
SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] [Step 2] Running: practice_environment_setup.sql >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;
INSERT @output EXEC xp_cmdshell @cmd;

-- Check for errors
IF EXISTS (SELECT 1 FROM @output WHERE line LIKE ''%error%'' OR line LIKE ''Msg %'' OR line LIKE ''Error%'')
BEGIN
    SELECT line AS [Deployment Messages] FROM @output
    WHERE line LIKE ''%error%'' OR line LIKE ''Msg %'' OR line LIKE ''Error%'' OR line LIKE ''%Warning%'';
    SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
    SET @echoCmd = N''echo ['' + @ts + ''] [Step 2] WARNINGS/ERRORS encountered (see job history) >> "'' + @logFile + ''"'';
    EXEC master.dbo.xp_cmdshell @echoCmd, no_output;
END

-- Log completion
SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] [Step 2] Practice environment deployment complete >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;

-- Disable xp_cmdshell
PRINT ''  Disabling xp_cmdshell...'';
EXEC sp_configure ''xp_cmdshell'', 0;
RECONFIGURE;
EXEC sp_configure ''show advanced options'', 0;
RECONFIGURE;

PRINT ''=== Practice database deployment complete ==='';
',
    @database_name = 'master',
    @on_success_action = 3,
    @on_fail_action = 2;
GO

-- =============================================
-- Step 3: Deploy DBATools and FRK scripts via sqlcmd
-- =============================================
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Deploy Practice Environment',
    @step_name = 'Deploy DBATools and FRK Scripts',
    @subsystem = 'PowerShell',
    @command = N'
$ErrorActionPreference = "Stop"
$OutputPath = "C:\DBATools\PracticeEnvironment"
$logDir = Join-Path $OutputPath "Logs"
$dateStr = Get-Date -Format yyyyMMdd
$logFile = Join-Path $logDir "deploy_$dateStr.log"

function Write-Log {
    param([string]$Message, [string]$ForegroundColor = "Gray")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp $Message" | Add-Content -Path $logFile -Encoding UTF8
    Write-Host $Message -ForegroundColor $ForegroundColor
}

Write-Log "========================================"
Write-Log "Deploying DBATools and FRK Scripts"
Write-Log "========================================"

function Execute-SqlFile {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { Write-Log "  File not found: $FilePath" -ForegroundColor Yellow; return $false }
    $log = [System.IO.Path]::GetTempFileName()
    $rc = 0
    $sqlcmd = "sqlcmd"
    if ((Get-Command "sqlcmd" -ErrorAction SilentlyContinue) -eq $null) {
        $paths = @("${env:ProgramFiles}\Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\110\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\120\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\130\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\140\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\150\Tools\Binn\SQLCMD.EXE",
                   "${env:ProgramFiles}\Microsoft SQL Server\160\Tools\Binn\SQLCMD.EXE",
                   "C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SQLCMD.EXE")
        foreach ($p in $paths) { if (Test-Path $p) { $sqlcmd = $p; break } }
    }
    try {
        & $sqlcmd -S "(local)" -E -C -d master -i "$FilePath" -b -o "$log" 2>&1 | Out-Null
        $rc = $LASTEXITCODE
        if ($rc -ne 0) {
            $err = Get-Content "$log" -Tail 3
            Write-Log ("    sqlcmd exit code " + $rc + ": " + $err) -ForegroundColor Yellow
        }
    } catch {
        Write-Log ("    Error: " + $_) -ForegroundColor Yellow
    } finally {
        if (Test-Path "$log") { Remove-Item "$log" -Force }
    }
    return ($rc -eq 0)
}

$dbScriptsPath = Join-Path $OutputPath "db-scripts"
$frkPath = Join-Path $OutputPath "SQL-Server-First-Responder-Kit-main"

# Deploy DBATools scripts in order (skip 06, 07, 08, 11B)
$dbatoolsPath = Join-Path (Join-Path $dbScriptsPath "sqlserver") "dbatools"
if (Test-Path $dbatoolsPath) {
    Write-Log "Deploying DBATools scripts..." -ForegroundColor Cyan
    $scripts = Get-ChildItem -Path $dbatoolsPath -Filter "*.sql" | Sort-Object Name
    foreach ($s in $scripts) {
        if ($s.Name -match "^(06|07|08|11B)_") { continue }
        $sName = $s.Name
        Write-Log "  $sName..." -NoNewline -ForegroundColor Gray
        try {
            Execute-SqlFile -FilePath $s.FullName | Out-Null
            Write-Log " OK" -ForegroundColor Green
        } catch {
            Write-Log " FAILED" -ForegroundColor Red
            Write-Log "    $_" -ForegroundColor Yellow
        }
    }
}

# Deploy First Responder Kit
Write-Log "`nDeploying First Responder Kit procedures..." -ForegroundColor Cyan
$frkScripts = @("sp_Blitz.sql", "sp_BlitzFirst.sql", "sp_BlitzIndex.sql", "sp_BlitzCache.sql")
foreach ($script in $frkScripts) {
    $sourceFile = Join-Path $frkPath $script
    if (Test-Path $sourceFile) {
        Write-Log "  $script..." -NoNewline -ForegroundColor Gray
        try {
            Execute-SqlFile -FilePath $sourceFile | Out-Null
            Write-Log " OK" -ForegroundColor Green
        } catch {
            Write-Log " FAILED" -ForegroundColor Red
        }
    }
}

Write-Log "`nScript deployment complete!" -ForegroundColor Green
',
    @database_name = 'master',
    @on_success_action = 3,
    @on_fail_action = 2;
GO

-- =============================================
-- Step 4: Verify deployment
-- =============================================
EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Deploy Practice Environment',
    @step_name = 'Verify Deployment',
    @subsystem = 'TSQL',
    @command = N'
SET NOCOUNT ON;
DECLARE @logDir NVARCHAR(500) = N''C:\DBATools\PracticeEnvironment\Logs'';
DECLARE @logFile NVARCHAR(500) = @logDir + N''\deploy_'' + CONVERT(NVARCHAR(8), GETDATE(), 112) + N''.log'';
DECLARE @ts NVARCHAR(20), @echoCmd NVARCHAR(1000);
DECLARE @procCount INT;

PRINT ''========================================'';
PRINT ''Deployment Complete!'';
PRINT ''========================================'';
PRINT ''Downloaded files: C:\DBATools\PracticeEnvironment'';
PRINT '';
PRINT ''Available Tools:'';

SELECT name AS [Deployed Procedures]
FROM sys.procedures
WHERE name LIKE ''sp_Blitz%''
  AND is_ms_shipped = 0
ORDER BY name;

-- Log completion to file via xp_cmdshell
SELECT @procCount = COUNT(*) FROM sys.procedures WHERE name LIKE ''sp_Blitz%'' AND is_ms_shipped = 0;

EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1;
RECONFIGURE;

SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] [Step 4] Verification complete - deployed '' + CAST(@procCount AS NVARCHAR(10)) + '' FRK procedures >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;
SET @ts = CONVERT(NVARCHAR(19), GETDATE(), 121);
SET @echoCmd = N''echo ['' + @ts + ''] ===== Deploy Finished ===== >> "'' + @logFile + ''"'';
EXEC master.dbo.xp_cmdshell @echoCmd, no_output;

EXEC sp_configure ''xp_cmdshell'', 0;
RECONFIGURE;
EXEC sp_configure ''show advanced options'', 0;
RECONFIGURE;
',
    @database_name = 'master',
    @on_success_action = 1,
    @on_fail_action = 2;
GO

EXEC msdb.dbo.sp_add_jobserver
    @job_name = 'DBATools - Deploy Practice Environment',
    @server_name = @@SERVERNAME;
GO

PRINT 'Job created: DBATools - Deploy Practice Environment (disabled by default)';
PRINT 'To enable and run:';
PRINT '  EXEC msdb.dbo.sp_update_job @job_name = ''DBATools - Deploy Practice Environment'', @enabled = 1;';
PRINT '  EXEC msdb.dbo.sp_start_job @job_name = ''DBATools - Deploy Practice Environment'';';
GO
