<#
.SYNOPSIS
    Delete all Azure resource groups whose name matches a wildcard pattern
    (default: BakingDP-Custom-*).

.DESCRIPTION
    Lists the matching resource groups first, then deletes them in parallel (-AsJob).
    Requires an authenticated Az context (Connect-AzAccount, or run inside an
    AzurePowerShell task / az-logged-in session). Supports -WhatIf and -Confirm.

.EXAMPLE
    # Dry run - show what would be deleted, delete nothing:
    ./delete-baking-custom-rgs.ps1 -WhatIf

.EXAMPLE
    # Delete without per-item prompts:
    ./delete-baking-custom-rgs.ps1 -Force

.EXAMPLE
    # Different pattern / subscription:
    ./delete-baking-custom-rgs.ps1 -NamePattern 'BakingDP-Preview-*' -SubscriptionId '739c4e86-...'
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$NamePattern = 'BakingDP-Custom-*',
    [string]$SubscriptionId,
    [switch]$Force   # skip the confirmation prompt
)

$ErrorActionPreference = 'Stop'

# Ensure we are logged in.
$context = Get-AzContext
if (-not $context) { throw "No Az context. Run Connect-AzAccount first." }

if ($SubscriptionId) {
    Write-Host "Selecting subscription $SubscriptionId ..."
    Set-AzContext -SubscriptionId $SubscriptionId | Out-Null
}
Write-Host "Subscription: $((Get-AzContext).Subscription.Name) ($((Get-AzContext).Subscription.Id))"

# Find matches (Get-AzResourceGroup accepts a wildcard on -Name).
$groups = @(Get-AzResourceGroup -Name $NamePattern -ErrorAction SilentlyContinue)

if ($groups.Count -eq 0) {
    Write-Host "No resource groups match '$NamePattern'. Nothing to do."
    return
}

Write-Host ""
Write-Host "The following $($groups.Count) resource group(s) match '$NamePattern':"
$groups | Select-Object ResourceGroupName, Location, @{n='ProvisioningState';e={$_.ProvisioningState}} |
    Format-Table -AutoSize | Out-Host

# Single confirmation for the whole batch. Skipped for -Force and for -WhatIf
# (ShouldContinue is NOT suppressed by -WhatIf, so guard it explicitly).
if (-not $Force -and -not $WhatIfPreference -and -not $PSCmdlet.ShouldContinue(
        "Delete these $($groups.Count) resource group(s) and ALL resources in them?",
        "Confirm deletion")) {
    Write-Host "Aborted. Nothing deleted."
    return
}

# Track the RG name alongside its job (Az job names are generic, not the RG name).
$deletions = @()
foreach ($rg in $groups) {
    if ($PSCmdlet.ShouldProcess($rg.ResourceGroupName, "Remove-AzResourceGroup")) {
        Write-Host "Starting delete: $($rg.ResourceGroupName)"
        $deletions += [pscustomobject]@{
            Name = $rg.ResourceGroupName
            Job  = Remove-AzResourceGroup -Name $rg.ResourceGroupName -Force -AsJob
        }
    }
}

if ($deletions.Count -eq 0) {
    if ($WhatIfPreference) {
        Write-Host "WhatIf: would delete $($groups.Count) resource group(s). No changes made."
    } else {
        Write-Host "No deletions issued."
    }
    return
}

Write-Host ""
Write-Host "Waiting for $($deletions.Count) delete job(s) to finish..."
$deletions.Job | Wait-Job | Out-Null

# Judge success by whether the RG is actually gone, not by the job's reported state:
# Remove-AzResourceGroup -AsJob can report Failed on a transient poller error even
# though the deletion completed.
$failed = @()
foreach ($d in $deletions) {
    Receive-Job -Job $d.Job -ErrorAction SilentlyContinue | Out-Null
    $stillExists = $null -ne (Get-AzResourceGroup -Name $d.Name -ErrorAction SilentlyContinue)
    if ($stillExists) {
        $failed += $d.Name
        Write-Host ("  {0,-40} {1}" -f $d.Name, "STILL EXISTS (job: $($d.Job.State))")
    } else {
        Write-Host ("  {0,-40} {1}" -f $d.Name, "Deleted")
    }
}
$deletions.Job | Remove-Job -Force -ErrorAction SilentlyContinue

if ($failed.Count -gt 0) {
    throw "$($failed.Count) resource group(s) still exist after deletion: $($failed -join ', '). Check the Azure portal."
}
Write-Host "All matching resource groups deleted."
