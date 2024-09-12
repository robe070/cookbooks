<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Virtual Machine Scale Sets in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when a VMSS is finished with for the moment. If the VMSS is tagged with ShutdownPolicy = Excluded, the VM is not stopped. Requires an Azure Automation Managed Identity account.

.VERSION 1.0.7

.GUID 5b97ae2e-b40a-458c-b34d-eda0e4d1f0d1

.AUTHOR Rob Goodridge

.COPYRIGHT (c) 2020 Rob Goodridge. All rights reserved.

.TAGS Azure Automation Cloud AzureAutomation AzureDevOps DevOps AzureRM Workflow Runbook VMSS

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
1.0.4: - Deal with 0 VMSS
1.0.5: - Change text
1.0.6: - Update to Managed Identity and Az Modules
1.0.7: - Edit synopsis
#>

<#
.SYNOPSIS
Stop or start all Virtual Machine Scale Sets in the current subscription or in a specific Resource Group, exclude by tag

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL VMSS in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the VMSS.
#>


workflow StopStartVMSS
{
    Param
    (
      [Parameter(Mandatory=$true)] [ValidateSet("Start","Stop")] [String]	$Action,
      [Parameter(Mandatory=$false)] [String] $AzureResourceGroup
    )

    try
    {
       "Logging in to Azure..."
       Connect-AzAccount -Identity
    }
    catch {
       Write-Error -Message $_.Exception
       throw $_.Exception
    }

    if ( $AzureResourceGroup ) {
        $VMSSs = @(Get-AzVmss -ResourceGroupName $AzureResourceGroup)
    } else {
        $VMSSs = @(Get-AzVmss)
    }

    if ( $VMSSs ) {
        $VMSSs.Name
        if ( $Action -eq "Stop")
        {
            Write-Output "Stopping VMSS"
            foreach -parallel ($VMSS in ($VMSSs) )
            {
                if ($VMSS.Tags["ShutdownPolicy"] -ne "Excluded" ) {
                    Write-Output "Stopping VMSS '$($VMSS.ResourceGroupName)/$($VMSS.name)'"
                    Stop-AzVmss -ResourceGroupName $VMSS.ResourceGroupName -VMScaleSetName $VMSS.name -Force -Verbose
                } else {
                    Write-Output "Skipping Excluded VMSS '$($VMSS.ResourceGroupName)/$($VMSS.name)'"
                }
            }
        }
        else
        {
            Write-Output "Starting VMSS"
            foreach -parallel ($VMSS in ($VMSSs) )
            {
                Write-Output "Starting VMSS '$($VMSS.ResourceGroupName)/$($VMSS.name)'"
                Start-AzVmss -ResourceGroupName $VMSS.ResourceGroupName -VMScaleSetName $VMSS.name -Verbose
            }
        }
    } else {
        Write-Output "There are 0 VMSS matching the criteria"
    }
}