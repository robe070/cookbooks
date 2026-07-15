<#
.SYNOPSIS
    Restart IIS on every instance of the deployed VMSS to clear WAS rapid-fail protection.

.DESCRIPTION
    Companion to create-azure-sql-login.ps1. Once the web login exists, any VMSS instance
    whose DefaultAppPool was disabled by rapid-fail protection (from the earlier lansaweb.dll
    access violations) will keep returning 503 until IIS is restarted. This enumerates the
    scale set instances and runs reset-iis-worker.ps1 on each via the Azure run-command
    channel (no inbound RDP/WinRM needed). Runs on the pipeline agent inside an Az context.

    Must run AFTER the login has been created and BEFORE the URL tests.

.EXAMPLE
    ./restart-vmss-iis.ps1 -deploymentOutput '$(deploymentOutput)' -ResourceGroup "$(resourceGroup)"
#>
param(
    [Parameter(Mandatory=$true)][string]$deploymentOutput, # ARM deploymentOutput JSON; supplies scalesetName
    [Parameter(Mandatory=$true)][string]$ResourceGroup     # resource group the VMSS was deployed into
)

$ErrorActionPreference = 'Stop'

$output   = ConvertFrom-Json $deploymentOutput
$vmssName = $output.scalesetName.value
if ([string]::IsNullOrWhiteSpace($vmssName)) { throw "deploymentOutput did not contain scalesetName.value" }

$worker = Join-Path $PSScriptRoot 'reset-iis-worker.ps1'
if (-not (Test-Path $worker)) { throw "Worker script not found: $worker" }

Write-Host "Restarting IIS on VMSS '$vmssName' (resource group '$ResourceGroup')..."

$instances = @(Get-AzVmssVM -ResourceGroupName $ResourceGroup -VMScaleSetName $vmssName)
if ($instances.Count -eq 0) { throw "No instances found in VMSS '$vmssName'" }

foreach ($vm in $instances) {
    Write-Host "--- Instance $($vm.InstanceId) ($($vm.Name)) ---"
    $result = Invoke-AzVmssVMRunCommand -ResourceGroupName $ResourceGroup -VMScaleSetName $vmssName `
        -InstanceId $vm.InstanceId -CommandId 'RunPowerShellScript' -ScriptPath $worker
    $result | Out-Default | Write-Host
}

Write-Host "IIS restart issued to all $($instances.Count) instance(s)."
