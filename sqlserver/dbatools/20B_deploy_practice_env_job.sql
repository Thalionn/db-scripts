USE msdb;
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

EXEC msdb.dbo.sp_add_jobstep
    @job_name = 'DBATools - Deploy Practice Environment',
    @step_name = 'Deploy Practice Environment',
    @subsystem = 'PowerShell',
    @command = N'
$ErrorActionPreference = "Stop"
$OutputPath = "C:\DBATools\PracticeEnvironment"

Write-Host "========================================"
Write-Host "SQL Server Practice Environment Auto-Deploy"
Write-Host "========================================"
Write-Host ""

# Create output directory
New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null

# =============================================
# FUNCTION: Execute SQL via SMO
# =============================================
function Execute-SqlFile {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath)) { Write-Host "  File not found: $FilePath" -ForegroundColor Yellow; return $false }
    $log = [System.IO.Path]::GetTempFileName()
    $rc = 0
    $sqlcmd = "sqlcmd"
    # Try common sqlcmd locations if not in PATH
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
            Write-Host ("    sqlcmd exit code " + $rc + ": " + $err) -ForegroundColor Yellow
        }
    } catch {
        Write-Host ("    Error: " + $_) -ForegroundColor Yellow
    } finally {
        if (Test-Path "$log") { Remove-Item "$log" -Force }
    }
    return ($rc -eq 0)
}

# =============================================
# FUNCTION: Download and extract GitHub repo ZIP
# =============================================
function Download-RepoZip {
    param([string]$RepoUrl, [string]$DestPath, [string]$RepoName)
    if (Test-Path $DestPath) { Write-Host "  $RepoName already exists, skipped" -ForegroundColor Gray; return }
    $zipFile = $DestPath + ".zip"
    try {
        Write-Host "  Downloading $RepoName..." -ForegroundColor Green
        Invoke-WebRequest -Uri $RepoUrl -OutFile $zipFile -UseBasicParsing -TimeoutSec 120
        # Extract to temp, then strip the single-root-folder that GitHub ZIPs always have
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
        Write-Host "  Downloaded: $RepoName" -ForegroundColor Green
    } catch {
        Write-Host ("  Failed to download " + $RepoName + ": " + $_) -ForegroundColor Yellow
    }
}

# =============================================
# 1. Download db-scripts
# =============================================
Write-Host "`n[1/5] Downloading db-scripts..." -ForegroundColor Cyan
$dbScriptsPath = Join-Path $OutputPath "db-scripts"
Download-RepoZip -RepoUrl "https://github.com/Thalionn/db-scripts/archive/refs/heads/main.zip" -DestPath $dbScriptsPath -RepoName "db-scripts"
# Fix path - GitHub adds branch name to extracted folder
if (-not (Test-Path (Join-Path $dbScriptsPath "sqlserver"))) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "db-scripts*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $dbScriptsPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName $dbScriptsPath.Split("\")[-1]
    }
}

# =============================================
# 2. Download First Responder Kit
# =============================================
Write-Host "`n[2/5] Downloading First Responder Kit..." -ForegroundColor Cyan
$frkPath = Join-Path $OutputPath "SQL-Server-First-Responder-Kit-main"
Download-RepoZip -RepoUrl "https://github.com/BrentOzarULTD/SQL-Server-First-Responder-Kit/archive/refs/heads/main.zip" -DestPath $frkPath -RepoName "First Responder Kit"
if (-not (Test-Path (Join-Path $frkPath "sp_Blitz.sql"))) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "SQL-Server-First-Responder-Kit*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $frkPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName ("SQL-Server-First-Responder-Kit-main")
    }
}

# =============================================
# 3. Download Ola Hallengren Maintenance Solution
# =============================================
Write-Host "`n[3/5] Downloading Ola Hallengren Maintenance Solution..." -ForegroundColor Cyan
$olaPath = Join-Path $OutputPath "sql-server-maintenance-solution-master"
Download-RepoZip -RepoUrl "https://github.com/olahallengren/sql-server-maintenance-solution/archive/refs/heads/master.zip" -DestPath $olaPath -RepoName "Maintenance Solution"
if (-not (Get-ChildItem -Path $olaPath -Filter "*.sql" -ErrorAction SilentlyContinue)) {
    $extracted = Get-ChildItem -Path $OutputPath -Directory | Where-Object { $_.Name -like "sql-server-maintenance-solution*" } | Select-Object -First 1
    if ($extracted) {
        Remove-Item $olaPath -Force -Recurse -ErrorAction SilentlyContinue
        Rename-Item $extracted.FullName ("sql-server-maintenance-solution-master")
    }
}

# =============================================
# 4. Deploy practice environment setup
# =============================================
Write-Host "`n[4/5] Deploying practice environment setup..." -ForegroundColor Cyan
$setupScript = Join-Path (Join-Path $dbScriptsPath "sqlserver") "practice_environment_setup.sql"
if (Test-Path $setupScript) {
    Write-Host "  Found: $setupScript" -ForegroundColor Green
    Execute-SqlFile -FilePath $setupScript
    Write-Host "  Deployed practice environment" -ForegroundColor Green
} else {
    Write-Host "  practice_environment_setup.sql not found" -ForegroundColor Yellow
}

# Deploy DBATools scripts in order
$dbatoolsPath = Join-Path (Join-Path $dbScriptsPath "sqlserver") "dbatools"
if (Test-Path $dbatoolsPath) {
    Write-Host "`n  Deploying DBATools scripts..." -ForegroundColor Cyan
    $scripts = Get-ChildItem -Path $dbatoolsPath -Filter "*.sql" | Sort-Object Name
    foreach ($s in $scripts) {
        if ($s.Name -match "^(06|07|08|11B)_") { continue }
        $sName = $s.Name
        Write-Host "    $sName..." -NoNewline -ForegroundColor Gray
        try {
            Execute-SqlFile -FilePath $s.FullName | Out-Null
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
            Write-Host "      $_" -ForegroundColor Yellow
        }
    }
}

# =============================================
# 5. Deploy First Responder Kit
# =============================================
Write-Host "`n[5/5] Deploying First Responder Kit procedures..." -ForegroundColor Cyan
$frkScripts = @("sp_Blitz.sql", "sp_BlitzFirst.sql", "sp_BlitzIndex.sql", "sp_BlitzCache.sql")
foreach ($script in $frkScripts) {
    $sourceFile = Join-Path $frkPath $script
    if (Test-Path $sourceFile) {
        Write-Host "  Deploying: $script..." -NoNewline -ForegroundColor Gray
        try {
            Execute-SqlFile -FilePath $sourceFile | Out-Null
            Write-Host " OK" -ForegroundColor Green
        } catch {
            Write-Host " FAILED" -ForegroundColor Red
        }
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Downloaded files: $OutputPath" -ForegroundColor Gray
Write-Host "`nAvailable Tools:" -ForegroundColor Yellow
try {
    $result = sqlcmd -S "(local)" -E -d master -Q "SET NOCOUNT ON; SELECT name FROM sys.procedures WHERE name LIKE ''sp_Blitz%'' AND is_ms_shipped = 0" -h -1 -W
    $result | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }
} catch { }
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
