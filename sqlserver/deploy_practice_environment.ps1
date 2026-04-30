# =============================================
# SQL Server Practice Environment Auto-Deploy Script
# Downloads and deploys practice databases from multiple sources
# =============================================

param(
    [string]$SqlServerInstance = "localhost",
    [string]$SqlUsername = "sa",
    [string]$SqlPassword = "",
    [string]$DatabaseName = "PracticeDB",
    [switch]$SkipDownload,
    [switch]$DryRun,
    [string]$OutputPath = ".\downloads"
)

# Configuration
$ErrorActionPreference = "Stop"

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

# =============================================
# FUNCTIONS
# =============================================

function Write-Header {
    param([string]$Title)
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "$Title" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Status {
    param([string]$Message, [string]$Color = "White")
    
    Write-Host "  $Message" -ForegroundColor $Color
}

function Test-SqlConnection {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName = "master",
        [string]$Username,
        [string]$Password
    )
    
    try {
        $connectionString = "Server=$ServerInstance;Database=$DatabaseName;TrustServerCertificate=True;"
        
        if ($Username) {
            $connectionString += "User ID=$Username;Password=$Password;"
        } else {
            $connectionString += "Integrated Security=True;"
        }
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $connection.Open()
        
        $command = $connection.CreateCommand()
        $command.CommandText = "SELECT @@VERSION"
        $result = $command.ExecuteScalar()
        
        $connection.Close()
        
        $version = $result -replace '.*?(Microsoft SQL Server \d{4}).*', '$1'
        Write-Host "Successfully connected to: $ServerInstance ($version)" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "Failed to connect to SQL Server: $_" -ForegroundColor Red
        return $false
    }
}

function Execute-SqlCommand {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName = "master",
        [string]$Username,
        [string]$Password,
        [string]$SqlScript
    )
    
    $connectionString = "Server=$ServerInstance;Database=$DatabaseName;TrustServerCertificate=True;"
    
    if ($Username) {
        $connectionString += "User ID=$Username;Password=$Password;"
    } else {
        $connectionString += "Integrated Security=True;"
    }
    
    $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
    $connection.Open()
    
    try {
        $command = $connection.CreateCommand()
        $command.CommandText = $SqlScript
        $command.CommandTimeout = 300
        
        $reader = $command.ExecuteReader()
        $table = New-Object System.Data.DataTable
        $table.Load($reader)
        
        return $table
    }
    finally {
        $connection.Close()
    }
}

function Execute-SqlFile {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName = "master",
        [string]$Username,
        [string]$Password,
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "File not found: $FilePath" -ForegroundColor Red
        return $false
    }
    
    $scriptContent = Get-Content -Path $FilePath -Raw
    
    # Split on GO statements for batch execution
    $batches = $scriptContent -split "^\s*GO\s*$", 0, "Multiline"
    
    foreach ($batch in $batches) {
        $batch = $batch.Trim()
        
        if ([string]::IsNullOrWhiteSpace($batch)) {
            continue
        }
        
        try {
            Execute-SqlCommand `
                -ServerInstance $ServerInstance `
                -DatabaseName $DatabaseName `
                -Username $Username `
                -Password $Password `
                -SqlScript $batch | Out-Null
        }
        catch {
            Write-Host "Error executing batch: $_" -ForegroundColor Yellow
            # Continue with next batch
        }
    }
    
    return $true
}

function Download-Repository {
    param(
        [string]$Owner,
        [string]$RepoName,
        [string]$Branch = "main",
        [string]$PathFilter
    )
    
    Write-Host "`n--- Downloading from: $Owner/$RepoName ---" -ForegroundColor Cyan
    
    try {
        $clonePath = Join-Path $OutputPath "$RepoName-$Branch"
        
        if (Test-Path $clonePath) {
            Write-Host "Repository already exists, updating..." -ForegroundColor Yellow
            $originalPath = Get-Location
            Set-Location $clonePath
            git pull origin $Branch
            Set-Location $originalPath
        } else {
            Write-Host "Cloning repository..." -ForegroundColor Green
            git clone --depth 1 --branch $Branch "https://github.com/$Owner/$RepoName.git" $clonePath
        }
        
        if ($PathFilter) {
            $filteredPath = Join-Path $clonePath $PathFilter
            if (Test-Path $filteredPath) {
                Write-Host "Filtered content available at: $filteredPath" -ForegroundColor Green
            } else {
                Write-Host "Filtered path not found: $PathFilter" -ForegroundColor Yellow
            }
        }
        
        return $true
    }
    catch {
        Write-Host "Failed to download repository: $_" -ForegroundColor Red
        return $false
    }
}

function Restore-DemoDatabase {
    param(
        [string]$BacpacFile,
        [string]$TargetDatabase
    )
    
    if (-not (Test-Path $BacpacFile)) {
        Write-Host "BACPAC file not found: $BacpacFile" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "`nRestoring demo database from: $BacpacFile" -ForegroundColor Cyan
    
    if (-not $DryRun) {
        try {
            Write-Host "BACPAC restore requires SqlPackage.exe or DBATools module" -ForegroundColor Yellow
            Write-Host "Manual restore command:" -ForegroundColor Gray
            Write-Host "  SqlPackage /Action:Import /SourceFile:`"$BacpacFile`" /TargetServerName:`"$SqlServerInstance`" /TargetDatabaseName:`"$TargetDatabase`" /TargetTrustServerCertificate:True" -ForegroundColor Gray
        }
        catch {
            Write-Host "Failed to restore database: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[DRY RUN] Would restore: $BacpacFile to $TargetDatabase" -ForegroundColor Yellow
    }
    
    return $true
}

# =============================================
# MAIN EXECUTION
# =============================================

Write-Header "SQL Server Practice Environment Auto-Deploy"

# Build connection params
$connParams = @{
    ServerInstance = $SqlServerInstance
    DatabaseName = "master"
}

if ($SqlUsername) {
    $connParams["Username"] = $SqlUsername
    $connParams["Password"] = $SqlPassword
}

# Check SQL Server connection
if (-not (Test-SqlConnection @connParams)) {
    Write-Host "Cannot connect to SQL Server instance: $SqlServerInstance" -ForegroundColor Red
    exit 1
}

# Download repositories if not skipped
if (-not $SkipDownload) {
    
    # 1. Download user's db-scripts repository
    Write-Host "`n[1/4] Downloading practice scripts..." -ForegroundColor Cyan
    
    try {
        $dbScriptsPath = Join-Path $OutputPath "db-scripts"
        if (-not (Test-Path $dbScriptsPath)) {
            git clone --depth 1 "https://github.com/Thalionn/db-scripts.git" $dbScriptsPath
            Write-Host "Successfully downloaded: db-scripts" -ForegroundColor Green
        } else {
            Write-Host "db-scripts already downloaded, skipping..." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "Failed to download db-scripts: $_" -ForegroundColor Red
    }
    
    # 2. Download Brent Ozar's First Responder Kit
    Write-Host "`n[2/4] Downloading First Responder Kit..." -ForegroundColor Cyan
    
    try {
        Download-Repository -Owner "BrentOzarULTD" -RepoName "SQL-Server-First-Responder-Kit" -Branch "main"
        Write-Host "Successfully downloaded: First Responder Kit" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download First Responder Kit: $_" -ForegroundColor Red
    }
    
    # 3. Download Ola Hallengren's Maintenance Solution
    Write-Host "`n[3/4] Downloading Ola Hallengren's Maintenance Solution..." -ForegroundColor Cyan
    
    try {
        Download-Repository -Owner "olahallengren" -RepoName "sql-server-maintenance-solution" -Branch "master"
        Write-Host "Successfully downloaded: Maintenance Solution" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to download Maintenance Solution: $_" -ForegroundColor Red
    }
    
    # 4. Download WideWorldImporters demo database
    Write-Host "`n[4/4] Downloading WideWorldImporters demo..." -ForegroundColor Cyan
    
    try {
        $wwiPath = Join-Path $OutputPath "WideWorldImporters"
        if (-not (Test-Path $wwiPath)) {
            $wwiUrl = "https://github.com/OneIdentity/WideWorldImporters/archive/refs/heads/master.zip"
            $tempZip = Join-Path $OutputPath "WideWorldImporters.zip"
            
            Write-Host "Downloading WideWorldImporters..." -ForegroundColor Green
            Invoke-WebRequest -Uri $wwiUrl -OutFile $tempZip
            
            Write-Host "Extracting..." -ForegroundColor Green
            Expand-Archive -Path $tempZip -DestinationPath $wwiPath -Force
            
            # Clean up zip
            Remove-Item $tempZip -Force
            
            # Look for BACPAC or SQL deployment script
            $bacpacFile = Get-ChildItem -Path $wwiPath -Recurse -Filter "*.bacpac" | Select-Object -First 1
            $deployScript = Get-ChildItem -Path $wwiPath -Recurse -Filter "Deploy-WideWorldImporters.sql" | Select-Object -First 1
            
            if ($bacpacFile) {
                Restore-DemoDatabase -BacpacFile $bacpacFile.FullName -TargetDatabase "WideWorldImporters"
            } elseif ($deployScript) {
                Write-Host "Found deployment script: $($deployScript.FullName)" -ForegroundColor Green
                Write-Host "Deploy manually:" -ForegroundColor Gray
                Write-Host "  sqlcmd -S $SqlServerInstance -i `"$($deployScript.FullName)`"" -ForegroundColor Gray
            } else {
                Write-Host "No BACPAC or deployment script found in WideWorldImporters" -ForegroundColor Yellow
            }
        } else {
            Write-Host "WideWorldImporters already downloaded, skipping..." -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "Failed to download WideWorldImporters: $_" -ForegroundColor Red
    }
}

# =============================================
# DEPLOY PRACTICE ENVIRONMENT SETUP
# =============================================

Write-Host "`n[5/7] Deploying practice environment setup..." -ForegroundColor Cyan

# Find the practice environment setup script
$scriptDir = Split-Path -Parent $PSCommandPath
$practiceSetup = Join-Path $scriptDir "practice_environment_setup.sql"

if (-not (Test-Path $practiceSetup)) {
    $practiceSetup = Join-Path $OutputPath "db-scripts\sqlserver\practice_environment_setup.sql"
}

if (Test-Path $practiceSetup) {
    Write-Host "Found practice setup script: $practiceSetup" -ForegroundColor Green
    
    try {
        Execute-SqlFile `
            -ServerInstance $SqlServerInstance `
            -DatabaseName "master" `
            -Username $connParams["Username"] `
            -Password $connParams["Password"] `
            -FilePath $practiceSetup
        
        Write-Host "Successfully deployed practice environment" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to deploy practice environment: $_" -ForegroundColor Red
    }
} else {
    Write-Host "practice_environment_setup.sql not found" -ForegroundColor Yellow
}

# =============================================
# DEPLOY YOUR SQL SCRIPTS
# =============================================

Write-Host "`n[6/7] Deploying SQL scripts..." -ForegroundColor Cyan

$sqlScriptsPath = Join-Path $OutputPath "db-scripts\sqlserver"
if (Test-Path $sqlScriptsPath) {
    $sqlFiles = Get-ChildItem -Path $sqlScriptsPath -Filter "*.sql" -Recurse | 
        Where-Object { $_.Name -ne "practice_environment_setup.sql" } |
        Sort-Object Name
    
    Write-Host "Found $($sqlFiles.Count) SQL scripts to deploy" -ForegroundColor Green
    
    foreach ($file in $sqlFiles) {
        $relativePath = $file.FullName.Substring($sqlScriptsPath.Length + 1)
        Write-Host "Deploying: $relativePath" -ForegroundColor Cyan
        
        try {
            Execute-SqlFile `
                -ServerInstance $SqlServerInstance `
                -DatabaseName "master" `
                -Username $connParams["Username"] `
                -Password $connParams["Password"] `
                -FilePath $file.FullName | Out-Null
            
            Write-Host "  Deployed: $($file.Name)" -ForegroundColor Green
        }
        catch {
            Write-Host "  Failed: $($file.Name) - $_" -ForegroundColor Red
        }
    }
}

# =============================================
# DEPLOY FIRST RESPONDER KIT (OPTIONAL)
# =============================================

Write-Host "`n[7/7] Deploying First Responder Kit procedures..." -ForegroundColor Cyan

$frkPath = Join-Path $OutputPath "SQL-Server-First-Responder-Kit-main"
if (Test-Path $frkPath) {
    $frkScripts = @(
        "sp_Blitz.sql",
        "sp_BlitzFirst.sql",
        "sp_BlitzIndex.sql",
        "sp_BlitzCache.sql"
    )
    
    foreach ($script in $frkScripts) {
        $sourceFile = Join-Path $frkPath $script
        if (Test-Path $sourceFile) {
            Write-Host "Deploying: $script" -ForegroundColor Cyan
            
            try {
                Execute-SqlFile `
                    -ServerInstance $SqlServerInstance `
                    -DatabaseName "master" `
                    -Username $connParams["Username"] `
                    -Password $connParams["Password"] `
                    -FilePath $sourceFile | Out-Null
                
                Write-Host "  Deployed: $script" -ForegroundColor Green
            }
            catch {
                Write-Host "  Failed: $script - $_" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "First Responder Kit not found (use -SkipDownload:false to download)" -ForegroundColor Yellow
}

# =============================================
# SUMMARY
# =============================================

Write-Header "Deployment Complete!"

Write-Host "Practice Environment Summary:" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

# Check for PracticeDB
$dbCheck = Execute-SqlCommand @connParams -SqlScript "SELECT name, create_date FROM sys.databases WHERE name = 'PracticeDB'"
if ($dbCheck -and $dbCheck.Rows.Count -gt 0) {
    Write-Host "  [OK] PracticeDB database created" -ForegroundColor Green
} else {
    Write-Host "  [--] PracticeDB not found" -ForegroundColor Yellow
}

# List deployed scripts
Write-Host "`nDeployed Scripts:" -ForegroundColor Yellow
if (Test-Path $sqlScriptsPath) {
    Get-ChildItem -Path $sqlScriptsPath -Filter "*.sql" -Recurse | 
        ForEach-Object {
            $relative = $_.FullName.Substring((Split-Path -Parent $sqlScriptsPath).Length + 1)
            Write-Host "  [OK] $relative" -ForegroundColor Green
        }
}

Write-Host "`nAvailable Tools:" -ForegroundColor Yellow

# Check for DBATools module
if (Get-Module -ListAvailable -Name dbatools -ErrorAction SilentlyContinue) {
    Write-Host "  [OK] DBATools PowerShell module installed" -ForegroundColor Green
    Write-Host "       Use: Connect-DbaInstance, Get-DbaDatabase, Invoke-DbaQuery" -ForegroundColor Gray
} else {
    Write-Host "  [--] DBATools not installed (optional)" -ForegroundColor Yellow
    Write-Host "       Install: Install-Module -Name dbatools -Scope CurrentUser" -ForegroundColor Gray
}

# Check for First Responder Kit
$frkProcs = Execute-SqlCommand @connParams -SqlScript "
    SELECT name FROM sys.procedures 
    WHERE name LIKE 'sp_Blitz%' AND is_ms_shipped = 0"
if ($frkProcs -and $frkProcs.Rows.Count -gt 0) {
    Write-Host "  [OK] First Responder Kit procedures deployed" -ForegroundColor Green
    $frkProcs.Rows | ForEach-Object { Write-Host "       - $($_.name)" -ForegroundColor Gray }
} else {
    Write-Host "  [--] First Responder Kit not deployed" -ForegroundColor Yellow
}

# Check for SQL Agent jobs
$jobs = Execute-SqlCommand @connParams -SqlScript "
    SELECT name, enabled, description FROM msdb.dbo.sysjobs 
    WHERE name LIKE 'SalesApp_%' OR name LIKE 'Practice_%' OR name LIKE 'WarehouseApp_%'
    ORDER BY name"
if ($jobs -and $jobs.Rows.Count -gt 0) {
    Write-Host "`nSQL Agent Jobs:" -ForegroundColor Yellow
    $jobs.Rows | ForEach-Object {
        $status = if ($_.enabled -eq 1) { "Enabled" } else { "Disabled" }
        Write-Host "  [$status] $($_.name)" -ForegroundColor Green
    }
}

Write-Host "`nDownloaded files: $OutputPath" -ForegroundColor Cyan
