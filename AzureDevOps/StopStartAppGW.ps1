<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Application Gateways in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when Application Gateways are finished with for the moment. If the Application Gateway is tagged with ShutdownPolicy = Excluded, the Application Gateway is not stopped. Requires an Azure Automation Managed Identity account.

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
1.0.4: - Update to Managed Identity and Az Modules
1.0.5: - Edit synopsis
1.0.6: - Remove dependency
#>

<#
.SYNOPSIS
Stop or start all Application Gateways in the current subscription or in a specific Resource Group, exclude by tag

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL Application Gateways in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the Application Gateways.
#>

workflow StopStartAppGW
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
        $AppGWs = @(Get-AzApplicationGateway -ResourceGroupName $AzureResourceGroup)
    } else {
        $AppGWs = @(Get-AzApplicationGateway )
    }

    $AppGWs.Name
    $AppGWs.OperationalState

    if ( $Action -eq "Stop")
    {
        Write-Output "Stopping Application Gateways"
        foreach -parallel ($AppGW in ($AppGWs) )
        {
            if ($AppGW.OperationalState -eq "running" -and (-not $AppGW.Tags -or $AppGW.Tags["ShutdownPolicy"] -ne "Excluded" ) ) {
                Write-Output "Stopping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
                Stop-AzApplicationGateway -ApplicationGateway $AppGW -Verbose
            } else {
                Write-Output "Skipping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
            }
        }
    }
    else
    {
        Write-Output "Starting Application Gateways"
        foreach -parallel ($AppGW in ($AppGWs) )
        {
            if ($AppGW.OperationalState -ne "running") {
                Write-Output "Starting Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
                Start-AzApplicationGateway -ApplicationGateway $AppGW -Verbose
            } else {
                Write-Output "Skipping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
            }
        }
    }
}