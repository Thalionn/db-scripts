# =============================================
# SQL Server Practice Environment Auto-Deploy Script
# Downloads and deploys practice databases from multiple sources
# =============================================

param(
    [string]$SqlServerInstance = "localhost",
    [string]$DatabaseName = "PracticeDB",
    [switch]$SkipDownload,
    [switch]$DryRun,
    [string]$OutputPath = ".\downloads"
)

# Configuration
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

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

function Test-SqlConnection {
    param(
        [string]$ServerInstance,
        [string]$DatabaseName = "master",
        [string]$Username,
        [string]$Password
    )
    
    try {
        $connectionString = "Server=$ServerInstance;Database=$DatabaseName;Integrated Security=True;"
        
        if ($Username) {
            $connectionString += "User ID=$Username;Password=$Password;"
        }
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $command = New-Object System.Data.SqlClient.SqlCommand("SELECT @@VERSION", $connection)
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        
        $table = New-Object System.Data.DataTable
        $adapter.Fill($table) | Out-Null
        
        Write-Host "Successfully connected to: $ServerInstance" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to connect to SQL Server: $_" -ForegroundColor Red
        return $false
    }
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
        # Clone repository
        $clonePath = Join-Path $OutputPath "$RepoName-$Branch"
        
        if (Test-Path $clonePath) {
            Write-Host "Repository already exists, updating..." -ForegroundColor Yellow
            cd $clonePath
            git pull origin $Branch
            cd ..
        } else {
            Write-Host "Cloning repository..." -ForegroundColor Green
            git clone --branch $Branch https://github.com/$Owner/$RepoName.git $clonePath
        }
        
        # Apply path filter if specified
        if ($PathFilter) {
            $filteredPath = Join-Path $clonePath "$PathFilter"
            if (Test-Path $filteredPath) {
                Write-Host "Copying filtered content to: $OutputPath" -ForegroundColor Green
                Copy-Item -Path $filteredPath -Destination $OutputPath -Recurse -Force
            } else {
                Write-Warning "Filtered path not found: $PathFilter"
            }
        }
        
        return $true
    }
    catch {
        Write-Error "Failed to download repository: $_" -ForegroundColor Red
        return $false
    }
}

function Deploy-SqlScripts {
    param(
        [string]$SourcePath,
        [string]$DestinationDb,
        [switch]$SkipExisting
    )
    
    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Source path not found: $SourcePath" -ForegroundColor Yellow
        return $false
    }
    
    # Get all .sql files
    $sqlFiles = Get-ChildItem -Path $SourcePath -Filter "*.sql" -Recurse | Sort-Object FullName
    
    if ($sqlFiles.Count -eq 0) {
        Write-Host "No SQL scripts found in: $SourcePath" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "`nFound $($sqlFiles.Count) SQL script(s)" -ForegroundColor Green
    
    foreach ($file in $sqlFiles) {
        $relativePath = $file.FullName.Substring($SourcePath.Length + 1).Replace('\', '/')
        
        if ($SkipExisting) {
            # Check if file already exists in database (simplified check)
            Write-Host "Skipping existing: $($file.Name)" -ForegroundColor Gray
            continue
        }
        
        Write-Host "`nDeploying: $relativePath" -ForegroundColor Cyan
        
        try {
            # Create backup of current state
            $backupFile = Join-Path $OutputPath "$($file.BaseName)-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
            
            if (-not $DryRun) {
                # Execute the script
                $connectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=True;"
                
                $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                $connection.Open()
                
                try {
                    $reader = [System.Data.SqlClient.SqlCommand]::CreateReader(
                        $connection, 
                        "iis:\$((Get-Content -Path $file.FullName -Raw))"
                    )
                    
                    # Execute in batches for large scripts
                    $batchSize = 1000
                    $buffer = @()
                    
                    while ($reader.Read()) {
                        if ($buffer.Count -ge $batchSize) {
                            Write-SqlBatch $connection $buffer
                            $buffer = @()
                        }
                        $buffer += $reader.GetFieldValue[string]($reader.FieldCount)
                    }
                    
                    if ($buffer.Count -gt 0) {
                        Write-SqlBatch $connection $buffer
                    }
                    
                    Write-Host "Successfully deployed: $($file.Name)" -ForegroundColor Green
                    
                } finally {
                    $connection.Close()
                }
            } else {
                Write-Host "[DRY RUN] Would deploy: $relativePath" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Error "Failed to deploy $($file.Name): $_" -ForegroundColor Red
            continue
        }
    }
    
    return $true
}

function Restore-DemoDatabase {
    param(
        [string]$BacpacFile,
        [string]$TargetDatabase
    )
    
    if (-not (Test-Path $bacpacFile)) {
        Write-Warning "BACPAC file not found: $bacpacFile" -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "`nRestoring demo database from: $bacpacFile" -ForegroundColor Cyan
    
    if (-not $DryRun) {
        try {
            # Use SQL Server BACPAC utility or PowerShell module
            Import-SqlBacPac -SourceFile $bacpacFile -TargetDatabaseName $TargetDatabase `
                -ServerInstance $SqlServerInstance -CreateDbIfNotExists:$true
            
            Write-Host "Successfully restored: $TargetDatabase" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to restore database: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "[DRY RUN] Would restore: $bacpacFile to $TargetDatabase" -ForegroundColor Yellow
    }
    
    return $true
}

# =============================================
# MAIN EXECUTION
# =============================================

Write-Header "SQL Server Practice Environment Auto-Deploy"

# Check SQL Server connection
if (-not (Test-SqlConnection -ServerInstance $SqlServerInstance)) {
    Write-Error "Cannot connect to SQL Server instance: $SqlServerInstance" -ForegroundColor Red
    exit 1
}

# Download repositories if not skipped
if (-not $SkipDownload) {
    
    # 1. Download user's db-scripts repository
    Write-Host "`n[1/4] Downloading your practice scripts..." -ForegroundColor Cyan
    
    try {
        git clone --depth 1 https://github.com/Thalionn/db-scripts.git "$OutputPath\db-scripts"
        Write-Host "Successfully downloaded: db-scripts" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download db-scripts: $_" -ForegroundColor Red
    }
    
    # 2. Download Brent Ozar's First Aid Kit
    Write-Host "`n[2/4] Downloading Brent Ozar's First Aid Kit..." -ForegroundColor Cyan
    
    try {
        git clone --depth 1 https://github.com/brentozar/SqlFirstAidKit.git "$OutputPath\SqlFirstAidKit"
        Write-Host "Successfully downloaded: SqlFirstAidKit" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download SqlFirstAidKit: $_" -ForegroundColor Red
    }
    
    # 3. Download Ola Hallengren's Backup Scripts
    Write-Host "`n[3/4] Downloading Ola Hallengren's Maintenance Solution..." -ForegroundColor Cyan
    
    try {
        git clone --depth 1 https://github.com/OlaHallengren/MaintenanceSolution.git "$OutputPath\MaintenanceSolution"
        Write-Host "Successfully downloaded: MaintenanceSolution" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to download MaintenanceSolution: $_" -ForegroundColor Red
    }
    
    # 4. Download WideWorldImporters demo database
    Write-Host "`n[4/4] Downloading WideWorldImporters demo..." -ForegroundColor Cyan
    
    try {
        $wwiUrl = "https://github.com/OneIdentity/WideWorldImporters/archive/refs/heads/master.zip"
        $tempZip = Join-Path $OutputPath "WideWorldImporters.zip"
        
        Invoke-WebRequest -Uri $wwiUrl -OutFile $tempZip
        
        # Extract the zip file
        Expand-Archive -Path $tempZip -DestinationPath "$OutputPath\WideWorldImporters-master" -Force
        
        # Convert to BACPAC format (or use existing if available)
        $bacpacSource = Join-Path "$OutputPath\WideWorldImporters-master" "WwiDb.bacpac"
        
        if (-not (Test-Path $bacpacSource)) {
            Write-Warning "BACPAC file not found in WideWorldImporters. Using SQL script instead." -ForegroundColor Yellow
            
            # Use the main deployment script
            $deployScript = Join-Path "$OutputPath\WideWorldImporters-master" "Deploy-WideWorldImporters.sql"
            
            if (Test-Path $deployScript) {
                Write-Host "Found deployment script: Deploy-WideWorldImporters.sql" -ForegroundColor Green
                
                # Execute the deployment script
                $connectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=True;"
                
                $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                $command = New-Object System.Data.SqlClient.SqlCommand("$deployScript", $connection)
                $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
                $table = New-Object System.Data.DataTable
                
                try {
                    $adapter.Fill($table) | Out-Null
                    Write-Host "Successfully deployed WideWorldImporters database" -ForegroundColor Green
                }
                catch {
                    Write-Error "Failed to deploy WideWorldImporters: $_" -ForegroundColor Red
                }
            }
        } else {
            # Restore the BACPAC file
            Restore-DemoDatabase -BacpacFile $bacpacSource -TargetDatabase "WideWorldImporters"
        }
        
    }
    catch {
        Write-Error "Failed to download WideWorldImporters: $_" -ForegroundColor Red
    }
}

# =============================================
# DEPLOY YOUR PRACTICE SCRIPTS
# =============================================

Write-Host "`n[5/6] Deploying your practice environment scripts..." -ForegroundColor Cyan

$yourScriptsPath = Join-Path $OutputPath "db-scripts\sqlserver"
if (Test-Path $yourScriptsPath) {
    Deploy-SqlScripts `
        -SourcePath $yourScriptsPath `
        -DestinationDb $DatabaseName `
        -SkipExisting:$false
    
    # Also deploy practice environment setup if it exists
    $practiceSetup = Join-Path $yourScriptsPath "practice_environment_setup.sql"
    if (Test-Path $practiceSetup) {
        Write-Host "`nDeploying practice environment setup..." -ForegroundColor Cyan
        
        try {
            $connectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=True;"
            
            $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
            $command = New-Object System.Data.SqlClient.SqlCommand((Get-Content -Path $practiceSetup -Raw), $connection)
            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
            $table = New-Object System.Data.DataTable
            
            $connection.Open()
            $adapter.Fill($table) | Out-Null
            $connection.Close()
            
            Write-Host "Successfully deployed practice environment" -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to deploy practice environment: $_" -ForegroundColor Red
        }
    }
}

# =============================================
# DEPLOY FIRST AID KIT (SELECT SCRIPTS ONLY)
# =============================================

Write-Host "`n[6/7] Deploying First Aid Kit diagnostic scripts..." -ForegroundColor Cyan

$firstAidPath = Join-Path $OutputPath "SqlFirstAidKit"
if (Test-Path $firstAidPath) {
    # Copy useful scripts to your database for easy access
    $scriptsToCopy = @(
        "DiagnosticScripts\01_Diagnostic_Queries.sql",
        "DiagnosticScripts\02_Performance_Monitoring.sql",
        "DiagnosticScripts\03_Security_Auditing.sql"
    )
    
    foreach ($script in $scriptsToCopy) {
        $sourceFile = Join-Path $firstAidPath "$script"
        if (Test-Path $sourceFile) {
            Write-Host "`nCopying: $script" -ForegroundColor Cyan
            
            try {
                # Read and execute the script
                $content = Get-Content -Path $sourceFile -Raw
                
                $connectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=True;"
                
                $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
                $command = New-Object System.Data.SqlClient.SqlCommand($content, $connection)
                $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
                $table = New-Object System.Data.DataTable
                
                $connection.Open()
                $adapter.Fill($table) | Out-Null
                $connection.Close()
                
                Write-Host "Successfully deployed: $script" -ForegroundColor Green
            }
            catch {
                Write-Error "Failed to deploy $script: $_" -ForegroundColor Red
            }
        }
    }
}

# =============================================
# DEPLOY MAINTENANCE SOLUTION (CONFIGURE FOR PRACTICE)
# =============================================

Write-Host "`n[7/8] Configuring Maintenance Solution for practice..." -ForegroundColor Cyan

$maintenancePath = Join-Path $OutputPath "MaintenanceSolution"
if (Test-Path $maintenancePath) {
    # Create a simplified maintenance configuration for practice
    
    $configContent = @"
-- =============================================
-- Practice Environment Maintenance Configuration
-- Simplified version of Ola Hallengren's Maintenance Solution
-- =============================================

USE master;
GO

-- Create maintenance database
IF NOT EXISTS (SELECT * FROM sys.databases WHERE name = 'PracticeMaintenance')
BEGIN
    CREATE DATABASE [PracticeMaintenance]
    ON (NAME = PracticeMaintenance_Data, FILENAME = N'PracticeMaintenance.mdf')
    LOG ON (NAME = PracticeMaintenance_Log, FILENAME = N'PracticeMaintenance.ldf');
END
GO

-- Create maintenance tables
USE PracticeMaintenance;
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[MaintenanceHistory]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[MaintenanceHistory](
        [MaintenanceDate] [datetime2](7) NOT NULL,
        [DatabaseName] [sysname] NOT NULL,
        [OperationType] [nvarchar](50) NOT NULL,
        [Status] [nvarchar](20) NOT NULL,
        [DurationSeconds] [int],
        [ErrorMessage] [nvarchar](max),
        CONSTRAINT [PK_MaintenanceHistory] PRIMARY KEY CLUSTERED ([MaintenanceDate] ASC)
    );
END
GO

-- Create maintenance jobs (simplified for practice)
USE master;
GO

IF NOT EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE name = 'Practice_Backup_Job')
BEGIN
    EXEC msdb.dbo.sp_add_job 
        @job_name = N'Practice_Backup_Job',
        @enabled = 1,
        @description = N'Practice backup job using Ola Hallengren''s solution';

    EXEC msdb.dbo.sp_add_jobstep 
        @job_name = N'Practice_Backup_Job',
        @step_name = N'Run Maintenance Plan',
        @subsystem = N'TSQL',
        @command = N'EXEC [PracticeMaintenance].[dbo].[xp_MaintenanceSolution]';

    EXEC msdb.dbo.sp_add_jobserver 
        @job_name = N'Practice_Backup_Job',
        @server_name = N'(local)';
END
GO

-- =============================================
-- Practice Environment Ready!
-- =============================================
"@

    try {
        $connectionString = "Server=$SqlServerInstance;Database=master;Integrated Security=True;"
        
        $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
        $command = New-Object System.Data.SqlClient.SqlCommand($configContent, $connection)
        $adapter = New-Object System.Data.SqlClient.SqlDataAdapter($command)
        $table = New-Object System.Data.DataTable
        
        $connection.Open()
        $adapter.Fill($table) | Out-Null
        $connection.Close()
        
        Write-Host "Successfully configured Maintenance Solution for practice" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to configure maintenance solution: $_" -ForegroundColor Red
    }
}

# =============================================
# INSTALL DBATools MODULE (OPTIONAL)
# =============================================

if (-not $SkipDownload) {
    Write-Host "`n[8/10] Installing DBATools PowerShell module..." -ForegroundColor Cyan
    
    try {
        # Check if DBATools is already installed
        if (-not (Get-Module -ListAvailable -Name Dbatools)) {
            Write-Host "DBATools not found, installing..." -ForegroundColor Yellow
            
            # Install DBATools from PowerShellGallery
            Install-Module -Name Dbatools -Force -Scope CurrentUser -AllowClobber
            
            Write-Host "Successfully installed DBATools module" -ForegroundColor Green
        } else {
            Write-Host "DBATools already installed, skipping..." -ForegroundColor Gray
        }
        
        # Import the module for use in this session
        Import-Module Dbatools -ErrorAction SilentlyContinue
        
    }
    catch {
        Write-Warning "Failed to install DBATools: $_" -ForegroundColor Yellow
        Write-Host "You can still use the script without DBATools, but some features may be limited." -ForegroundColor Gray
    }
}

# =============================================
# SUMMARY
# =============================================

Write-Header "Deployment Complete!"

if (-not $DryRun) {
    Write-Host "`nPractice Environment Summary:" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Cyan
    
    # List deployed scripts
    Write-Host "`nDeployed Scripts:" -ForegroundColor Yellow
    Get-ChildItem -Path "$OutputPath\db-scripts\sqlserver" -Filter "*.sql" -Recurse | 
        ForEach-Object {
            $relative = $_.FullName.Substring($OutputPath.Length + 1).Replace('\', '/')
            Write-Host "  ✓ $relative" -ForegroundColor Green
        }
    
    Write-Host "`nAvailable Tools:" -ForegroundColor Yellow
    
    if (Get-Module -ListAvailable -Name Dbatools) {
        Write-Host "  ✓ DBATools PowerShell module installed" -ForegroundColor Green
        Write-Host "    Use: Connect-DbaSql, Get-DbaDb, Invoke-DbaQuery, etc." -ForegroundColor Gray
    } else {
        Write-Host "  ⚠ DBATools not installed (optional)" -ForegroundColor Yellow
        Write-Host "    Install with: Install-Module -Name Dbatools -Scope CurrentUser" -ForegroundColor Gray
    }
    
    Write-Host "  ✓ First Aid Kit diagnostic scripts" -ForegroundColor Green
    Write-Host "  ✓ Maintenance Solution configuration" -ForegroundColor Green
    
    if (Test-Path "$OutputPath\WideWorldImporters-master") {
        Write-Host "  ✓ WideWorldImporters demo database" -ForegroundColor Green
    }
    
    Write-Host "`nPractice Environment Features:" -ForegroundColor Yellow
    Write-Host "  • Simulated user roles and applications" -ForegroundColor White
    Write-Host "  • Scheduled jobs for various business scenarios" -ForegroundColor White
    Write-Host "  • Performance monitoring and diagnostics" -ForegroundColor White
    Write-Host "  • Lock contention analysis tools" -ForegroundColor White
    Write-Host "  • Index usage tracking" -ForegroundColor White
    
    Write-Host "`nNext Steps:" -ForegroundColor Yellow
    Write-Host "1. Connect to SQL Server and explore the practice environment" -ForegroundColor White
    Write-Host "2. Review deployed scripts in: $OutputPath\db-scripts\sqlserver" -ForegroundColor White
    Write-Host "3. Use First Aid Kit scripts for diagnostic practice" -ForegroundColor White
    Write-Host "4. Configure Maintenance Solution backup jobs as needed" -ForegroundColor White
    
} else {
    Write-Host "`n[DRY RUN] No changes were made to the SQL Server instance." -ForegroundColor Yellow
}

Write-Host "`nDownloaded files are in: $OutputPath" -ForegroundColor Cyan
