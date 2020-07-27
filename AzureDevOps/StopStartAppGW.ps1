<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Application Gateways in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when Application Gateways are finished with for the moment. If the Application Gateway is tagged with ShutdownPolicy = Excluded, the Application Gateway is not stopped. Requires an Azure Automation account with an Azure Run As account credential.

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
1.0.4: - Deal with 0 Application Gateways
1.0.5: - Fix ShutdownPolicy Excluded
1.0.6: - Reduce log output and detect result of stop/start operation
#>

<#
.SYNOPSIS
Stop or start all Application Gateways in the current subscription or in a specific Resource Group

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL Application Gateways in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the Application Gateways.
#>

#Requires -Modules Connect-AzureAutomation
# import-module .\Connect-AzureAutomation

workflow StopStartAppGW
{
    Param
    (
        [Parameter(Mandatory=$false)] [String] $AzureResourceGroup,
	    [Parameter(Mandatory=$true)] [ValidateSet("Start","Stop")] [String]	$Action
    )

    Connect-AzureAutomation

    if ( $AzureResourceGroup ) {
        $AppGWs = @(Get-AzureRmApplicationGateway -ResourceGroupName $AzureResourceGroup)
    } else {
        $AppGWs = @(Get-AzureRmApplicationGateway )
    }

    if ( $AppGWs ) {
        $AppGWs.Name
        $AppGWs.OperationalState

        if ( $Action -eq "Stop")
        {
            Write-Output "Stopping Application Gateways"
            foreach -parallel ($AppGW in ($AppGWs) )
            {
                if ($AppGW.OperationalState -eq "running" -and (-not $AppGW.Tag -or $AppGW.Tag["ShutdownPolicy"] -ne "Excluded" ) ) {
                    Write-Output "Stopping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
                    $StopAG = Stop-AzureRmApplicationGateway -ApplicationGateway $AppGW -Verbose
                    if ( $StopAG.OperationalState -eq 'Stopped' ) {
                        Write-Output "$($StopAG.name) successfully stopped"
                    } else {
                        Write-Error "$($StopAG.name) failed to stop. Current state = $($StopAG.OperationalState)"
                    }
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
                    Start-AzureRmApplicationGateway -ApplicationGateway $AppGW -Verbose
                    if ( $StartAG.OperationalState -eq 'Running' ) {
                        Write-Output "$($StartAG.name) successfully started"
                    } else {
                        Write-Error "$($StartAG.name) failed to start. Current state = $($StartAG.OperationalState)"
                    }
                } else {
                    Write-Output "Skipping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
                }
            }
        }
    } else {
        Write-Output "There are 0 Application Gateways matching the criteria"
    }
}