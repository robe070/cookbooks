param (
    [switch]$DryRun
)

#Import-Module AWS.Tools.RDS
#Import-Module AWS.Tools.Common

$PollInterval = 30

# Get all regions but exclude ISO (us-iso-*) and GovCloud (us-gov-*)
$regions = Get-AWSRegion | Select-Object -ExpandProperty Region | Where-Object {
    ($_ -notlike "us-iso*") -and ($_ -notlike "us-gov-*")
}

$targets = @()

# ---------- DISCOVERY PHASE ----------
foreach ($region in $regions) {

    Write-Host "`n--- Scanning Region: $region ---" -ForegroundColor Cyan

    try {
        $instances = Get-RDSDBInstance -Region $region -ErrorAction Stop | Where-Object {
            $_.PerformanceInsightsEnabled -eq $true
        }

        foreach ($db in $instances) {
            $targets += [PSCustomObject]@{
                Region     = $region
                Identifier = $db.DBInstanceIdentifier
                Status     = $db.DBInstanceStatus
                Engine     = $db.Engine
            }
        }

    } catch {
        Write-Warning "Failed to access RDS in $region. Skipping. $_"
    }
}

if (-not $targets) {
    Write-Host "No RDS instances with Performance Insights enabled found in allowed regions."
    return
}

# Audit output
$targets | Format-Table -AutoSize

if ($DryRun) {
    #Write-Host "`nDRY-RUN MODE ENABLED — no changes will be made." -ForegroundColor Yellow
    return
}

# ---------- CONFIRMATION ----------
$confirmation = Read-Host "`nProceed to disable Performance Insights on ALL listed instances? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Operation cancelled."
    return
}

# ---------- EXECUTION PHASE ----------
foreach ($target in $targets) {

    $dbId = $target.Identifier
    $region = $target.Region

    # Refresh instance state
    try {
        $db = Get-RDSDBInstance -DBInstanceIdentifier $dbId -Region $region -ErrorAction Stop
        $status = $db.DBInstanceStatus
    } catch {
        Write-Warning "Failed to retrieve $dbId in $region. Skipping. $_"
        continue
    }

    # Start instance if stopped
    if ($status -eq "stopped") {
        Write-Host "Starting instance $dbId ($region)..."
        try {
            Start-RDSDBInstance -DBInstanceIdentifier $dbId -Region $region -ErrorAction Stop | Out-Null
        } catch {
            Write-Warning "Failed to start $dbId in $region. Skipping. $_"
            continue
        }

        do {
            Start-Sleep -Seconds $PollInterval
            $status = (Get-RDSDBInstance -DBInstanceIdentifier $dbId -Region $region).DBInstanceStatus
        } while ($status -ne "available")
    }

    # Disable Performance Insights
    Write-Host "Disabling Performance Insights on $dbId ($region)..."
    try {
        Edit-RDSDBInstance `
            -DBInstanceIdentifier $dbId `
            -EnablePerformanceInsights $false `
            -ApplyImmediately $true `
            -Confirm:$false `
            -Region $region | Out-Null
    } catch {
        Write-Warning "Failed to disable Performance Insights on $dbId in $region. $_"
        continue
    }

    # Wait for modify completion
    Write-Host "Waiting for modification to complete on $dbId ($region)..."
    do {
        Start-Sleep -Seconds $PollInterval
        $status = (Get-RDSDBInstance -DBInstanceIdentifier $dbId -Region $region).DBInstanceStatus
    } while ($status -notin @("available", "stopped"))

    Write-Host "$dbId in $region is now $status"
}

Write-Host "`nAll modifications completed successfully."
