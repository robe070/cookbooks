<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Application Gateways in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when Application Gateways are finished with for the moment. If the Application Gateway is tagged with ShutdownPolicy = Excluded, the Application Gateway is not stopped. Application Gateways are also not stopped if it is already managed by a schedule. Requires an Azure Automation account with an Azure Run As account credential.

.VERSION 1.0.2

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

#>

<#
.SYNOPSIS
Stop or start all Application Gateways in the current subscription or in a specific Resource Group

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL Application Gateways in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the Application Gateways.
#>

workflow StopStartAppGW
{
    Param
    (
        [Parameter(Mandatory=$false)] [String] $AzureResourceGroup,
	    [Parameter(Mandatory=$true)] [ValidateSet("Start","Stop")] [String]	$Action
    )

# Use the Run As connection to login to Azure
function Login-AzureAutomation([bool] $AzModuleOnly, [String]$AzureEnvironment = 'AzureCloud') {
    try {
        $RunAsConnection = Get-AutomationConnection -Name "AzureRunAsConnection"
        Write-Output "Logging in to Azure ($AzureEnvironment)..."

        if (!$RunAsConnection.ApplicationId) {
            $ErrorMessage = "Connection 'AzureRunAsConnection' is incompatible type."
            throw $ErrorMessage
        }

        if ($AzModuleOnly) {
            Connect-AzAccount `
                -ServicePrincipal `
                -TenantId $RunAsConnection.TenantId `
                -ApplicationId $RunAsConnection.ApplicationId `
                -CertificateThumbprint $RunAsConnection.CertificateThumbprint `
                -Environment $AzureEnvironment

            Select-AzSubscription -SubscriptionId $RunAsConnection.SubscriptionID  | Write-Verbose
        } else {
            Add-AzureRmAccount `
                -ServicePrincipal `
                -TenantId $RunAsConnection.TenantId `
                -ApplicationId $RunAsConnection.ApplicationId `
                -CertificateThumbprint $RunAsConnection.CertificateThumbprint `
                -Environment $AzureEnvironment

            Select-AzureRmSubscription -SubscriptionId $RunAsConnection.SubscriptionID  | Write-Verbose
        }
    } catch {
        if (!$RunAsConnection) {
            $RunAsConnection | fl | Write-Output
            Write-Output $_.Exception
            $ErrorMessage = "Connection 'AzureRunAsConnection' not found."
            throw $ErrorMessage
        }

        throw $_.Exception
    }
}

    Login-AzureAutomation

    if ( $AzureResourceGroup ) {
        $AppGWs = @(Get-AzureRmApplicationGateway -ResourceGroupName $AzureResourceGroup)
    } else {
        $AppGWs = @(Get-AzureRmApplicationGateway )
    }

    $AppGWs.Name
    $AppGWs.OperationalState

    if ( $Action -eq "Stop")
    {
        Write-Output "Stopping Application Gateways"
        foreach -parallel ($AppGW in ($AppGWs) )
        {
            if ($AppGW.OperationalState -eq "running" -and $AppGW.Tags["ShutdownPolicy"] -ne "Excluded" )  {
                Write-Output "Stopping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
                Stop-AzureRmApplicationGateway -ApplicationGateway $AppGW -Verbose
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
            } else {
                Write-Output "Skipping Application Gateway '$($AppGW.ResourceGroupName)/$($AppGW.name)'"
            }
        }
    }
}