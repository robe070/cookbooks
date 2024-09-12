<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Virtual Machines in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when VMs are finished with for the moment. If the VM is tagged with ShutdownPolicy = Excluded, the VM is not stopped. VMs are also not stopped if it is already managed by a schedule. Requires an Azure Automation account with an Azure Run As account credential.

.VERSION 1.0.4

.GUID 81441e5f-d154-4666-97cf-b8f3decb9341

.AUTHOR Rob Goodridge

.COPYRIGHT (c) 2020 Rob Goodridge. All rights reserved.

.TAGS Azure Automation Cloud AzureAutomation AzureDevOps DevOps AzureRM Workflow Runbook

.LICENSEURI

.PROJECTURI

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
1.0.1: - Add initial version
1.0.2: - Gallery text changes
1.0.3: - Use Connect-AzureAutomation module
1.0.4: - Deal with 0 VMs

#>

<#
.SYNOPSIS
Stop or start all Virtual Machines in the current subscription or in a specific Resource Group

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL VMs in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the VMs.
#>

#Requires -Modules Connect-AzureAutomation

workflow StopStartVM
{
    Param
    (
        [Parameter(Mandatory=$false)] [String] $AzureResourceGroup,
	    [Parameter(Mandatory=$true)] [ValidateSet("Start","Stop")] [String]	$Action
    )

    Connect-AzureAutomation

    $DevTestLabs = Get-AzureRmResource | Where-Object {$_.ResourceType -eq "Microsoft.DevTestLab/schedules"}
    if ( $AzureResourceGroup ) {
        $VMs = @(Get-AzureRmVM -ResourceGroupName $AzureResourceGroup -Status | Select-Object ResourceGroupName,Name,Location, tags, @{ label = “VMStatus”; Expression = { $_.PowerState } })
    } else {
        $VMs = @(Get-AzureRmVM -Status | Select-Object ResourceGroupName,Name,Location, tags, @{ label = “VMStatus”; Expression = { $_.PowerState } })
    }

    if ( $VMs ) {
        $VMs.Name

        if ( $Action -eq "Stop")
        {
            Write-Output "Stopping VMs"
            foreach -parallel ($vm in ($VMs) )
            {
                $ShutDownName = "shutdown-computevm-{0}" -f $vm.Name

                if ($vm.VMStatus -eq "VM running" -and $vm.Tags["ShutdownPolicy"] -ne "Excluded" -and (-not $DevTestLabs -or ($DevTestLabs.Name -notcontains $ShutdownName) )) {
                    Write-Output "Stopping VM '$($vm.ResourceGroupName)/$($vm.name)'"
                    Stop-AzureRmVm -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -Force -Verbose
                } else {
                    Write-Output "Skipping VM '$($vm.ResourceGroupName)/$($vm.name)'"
                }
            }
        }
        else
        {
            Write-Output "Starting VMs"
            foreach -parallel ($vm in ($VMs) )
            {
                if ($vm.VMStatus -ne "VM running") {
                    Write-Output "Starting VM '$($vm.ResourceGroupName)/$($vm.name)'"
                    Start-AzureRmVm -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -Verbose
                } else {
                    Write-Output "Skipping VM '$($vm.ResourceGroupName)/$($vm.name)'"
                }
            }
        }
    } else {
        Write-Output "There are 0 VMs matching the criteria"
    }
}