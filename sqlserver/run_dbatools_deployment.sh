#!/bin/bash
# ============================================================================
# DBATools Deployment Script
# Runs all dbatools SQL scripts in correct order on SQL servers
# ============================================================================

# Configuration
# IMPORTANT: Set SQL_PASS as environment variable or edit below
SQL_USER="zed"
SQL_PASS="${SQL_PASS:-YOUR_PASSWORD_HERE}"
SCRIPT_DIR="/Users/drew/Documents/Repo/db-scripts/sqlserver/dbatools"
LOG_DIR="/tmp/dbatools_deployment_$(date +%Y%m%d_%H%M%S)"

# Create log directory
mkdir -p "$LOG_DIR"

# List of scripts in correct execution order (skip problematic ones)
# Format: "filename|description"
declare -a SCRIPTS=(
    "00_create_database.sql|Create DBATools Database"
    "01_tables.sql|Create Tables"
    "02_procedures.sql|Create Procedures"
    "03_views.sql|Create Views"
    "04_functions.sql|Create Functions"
    "05_jobs.sql|Create Agent Jobs"
    "09_security_audit.sql|Security Audit Tables"
    "09B_security_jobs.sql|Security Audit Jobs"
    "10_errorlog_parser.sql|Error Log Parser"
    "11_alert_framework.sql|Alert Framework"
    "11C_alert_jobs.sql|Alert Jobs"
    "12_capacity_planning.sql|Capacity Planning"
    "13_tempdb_contention.sql|TempDB Contention"
    "14_ag_replica_health.sql|AG Replica Health"
    "15_index_recommendations.sql|Index Recommendations"
    "16_baseline_comparison.sql|Baseline Comparison"
    "17_documentation.sql|Documentation"
    "18_duplicate_indexes.sql|Duplicate Indexes"
    "19_login_transfer.sql|Login Transfer"
    "20_html_report.sql|HTML Report"
)

# Skipped scripts (manual deployment required):
# - 06_login_trigger.sql (causes login issues)
# - 07_ola_backup_template.sql (requires Ola Hallengren)
# - 08_index_maintenance_job.sql (requires Ola Hallengren)
# - 11B_mail_setup.sql (requires SMTP)

# Function to run SQL file on a server
run_sql_script() {
    local SERVER=$1
    local FILE=$2
    local DESC=$3
    local LOG_FILE="$LOG_DIR/${SERVER}_$(basename $FILE .sql).log"

    echo "  [$SERVER] Deploying: $DESC"
    echo "           File: $FILE"

    sqlcmd -S "$SERVER" -U "$SQL_USER" -P "$SQL_PASS" \
        -i "$SCRIPT_DIR/$FILE" \
        -o "$LOG_FILE" 2>&1

    # Check for errors (but continue on non-fatal errors)
    if grep -qi "error\|failed\|invalid" "$LOG_FILE" 2>/dev/null; then
        echo "           ⚠️  Warnings detected (check log: $LOG_FILE)"
        # Don't exit - many "errors" are just "already exists" type messages
    else
        echo "           ✅ Success"
    fi
    echo ""
}

# Function to deploy all scripts to a server
deploy_to_server() {
    local SERVER=$1

    echo "========================================"
    echo "  Deploying to: $SERVER"
    echo "========================================"
    echo ""

    # Test connection first
    echo "Testing connection to $SERVER..."
    if ! sqlcmd -S "$SERVER" -U "$SQL_USER" -P "$SQL_PASS" \
        -Q "SELECT @@VERSION;" -o "$LOG_DIR/${SERVER}_connection_test.log" 2>&1 | grep -q "Copyright"; then
        echo "❌ Failed to connect to $SERVER"
        echo "   Check server name, credentials, and network connectivity"
        return 1
    fi
    echo "✅ Connected successfully"
    echo ""

    # Run each script in order
    for entry in "${SCRIPTS[@]}"; do
        FILE=$(echo "$entry" | cut -d'|' -f1)
        DESC=$(echo "$entry" | cut -d'|' -f2)
        run_sql_script "$SERVER" "$FILE" "$DESC"
    done

    echo "========================================"
    echo "  Deployment to $SERVER complete!"
    echo "========================================"
    echo ""
}

# Main execution
echo "========================================"
echo "  DBATools Deployment Script"
echo "========================================"
echo "  Log directory: $LOG_DIR"
echo "========================================"
echo ""

# Deploy to SQL2022
deploy_to_server "SQL2022"

# Deploy to SQL2025
deploy_to_server "SQL2025"

# Summary
echo "========================================"
echo "  DEPLOYMENT SUMMARY"
echo "========================================"
echo "Logs saved to: $LOG_DIR"
echo ""

for SERVER in SQL2022 SQL2025; do
    echo "[$SERVER] Checking deployed objects..."

    # Check databases
    sqlcmd -S "$SERVER" -U "$SQL_USER" -P "$SQL_PASS" \
        -Q "SELECT name, create_date FROM sys.databases WHERE name IN ('DBATools', 'PracticeDB');" \
        2>&1 | grep -E "DBATools|PracticeDB" || echo "  No databases found"

    # Check tables
    sqlcmd -S "$SERVER" -U "$SQL_USER" -P "$SQL_PASS" \
        -d DBATools \
        -Q "SELECT name FROM sys.tables WHERE schema_id = SCHEMA_ID('dba') ORDER BY name;" \
        2>&1 | head -20 || echo "  No tables found"

    echo ""
done

echo "========================================"
echo "  Deployment Complete!"
echo "========================================"
echo ""
echo "Skipped scripts (deploy manually if needed):"
echo "  - 06_login_trigger.sql"
echo "  - 07_ola_backup_template.sql"
echo "  - 08_index_maintenance_job.sql"
echo "  - 11B_mail_setup.sql"
echo ""
# ```
#  
# This shell script:
#  
# 1. Defines configuration - SQL credentials and script directory
# 2. Lists scripts in correct order - With descriptions
# 3. Has run_sql_script function - Runs each SQL file and logs output
# 4. Has deploy_to_server function - Deploys all scripts to one server
# 5. Tests connectivity - Before deploying to each server
# 6. Provides summary - At the end showing deployed objects
# 7. Logs everything - To a timestamped directory in /tmp
# 8. Skips problematic scripts - Lists them at the end
#  
# To run it:
# bash
# chmod +x /Users/drew/Documents/Repo/db-scripts/sqlserver/run_dbatools_deployment.sh
# /Users/drew/Documents/Repo/db-scripts/sqlserver/run_dbatools_deployment.sh
