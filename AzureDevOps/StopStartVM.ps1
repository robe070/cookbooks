<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Virtual Machines in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when VMs are finished with for the moment. If the VM is tagged with ShutdownPolicy = Excluded, the VM is not stopped. VMs are also not stopped if it is already managed by a schedule. May exclude VMs using tag. Requires an Azure Automation account using System Managed Identity.

.VERSION 1.0.6

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
1.0.5: - Update to Managed Identity and Az Modules
1.0.6: - Edit synopsis

#>

<#
.SYNOPSIS
Stop or start all Virtual Machines in the current subscription or in a specific Resource Group, exclude by tag

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL VMs in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the VMs.
#>

workflow StopStartVM
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

   $DevTestLabs = Get-AzResource | Where-Object {$_.ResourceType -eq "Microsoft.DevTestLab/schedules"}

   $RGIsNull = [String]::IsNullOrWhiteSpace($AzureResourceGroup)
   if ( $RGIsNull  ) {
      "All VMs"
      $VMs = Get-AzVM -Status

      # $VMs = @(Get-AzureRmVM -Status | Select-Object ResourceGroupName,Name,Location, tags, @{ label = "VMStatus"; Expression = { $_.PowerState } })
   } else {
      "Resource Group filter $AzureResourceGroup"
      $VMs = @(Get-AzVM -ResourceGroupName $AzureResourceGroup -Status)
   }

   "Processing VMs"
   if ( $VMs ) {
      # $VMs
      if ( $Action -eq "Stop")
      {
         Write-Output "Stopping VMs"
         foreach -parallel ($vm in ($VMs) )
         {
            $vm.Name
            $ShutDownName = "shutdown-computevm-{0}" -f $vm.Name

            if ($vm.PowerState -eq "VM running" -and $vm.Tags["ShutdownPolicy"] -ne "Excluded" -and (-not $DevTestLabs -or ($DevTestLabs.Name -notcontains $ShutdownName) )) {
               Write-Output "Stopping VM '$($vm.ResourceGroupName)/$($vm.name)'"
               Stop-AzVm -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -Force -Verbose
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
            $vm.Name
            if ($vm.PowerState -ne "VM running") {
               Write-Output "Starting VM '$($vm.ResourceGroupName)/$($vm.name)'"
               Start-AzVm -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -Verbose
            } else {
               Write-Output "Skipping VM '$($vm.ResourceGroupName)/$($vm.name)'"
            }
         }
      }
      "Runbook Complete"
   } else {
      Write-Output "There are 0 VMs matching the criteria"
   }
}