<#
.SYNOPSIS
    Runs ON a VMSS instance (via Invoke-AzVmssVMRunCommand) to clear WAS rapid-fail state.

.DESCRIPTION
    After the Azure SQL web login is created post-MSI, any instance whose DefaultAppPool
    already tripped WAS rapid-fail protection (because lansaweb.dll access-violated when the
    login was missing) stays disabled and returns 503. Restarting IIS clears that state and
    lets the plugin reconnect now that the login exists.
#>
$ErrorActionPreference = 'Continue'

Write-Host "Restarting IIS to clear WAS rapid-fail protection..."
iisreset /restart

Import-Module WebAdministration -ErrorAction SilentlyContinue

$pool = 'DefaultAppPool'
$state = (Get-WebAppPoolState -Name $pool -ErrorAction SilentlyContinue).Value
if ($state -ne 'Started') {
    Write-Host "$pool is '$state'; starting it."
    Start-WebAppPool -Name $pool -ErrorAction SilentlyContinue
}
$state = (Get-WebAppPoolState -Name $pool -ErrorAction SilentlyContinue).Value
Write-Host "$pool state: $state"
