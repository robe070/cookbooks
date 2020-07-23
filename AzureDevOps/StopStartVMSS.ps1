<#PSScriptInfo

.DESCRIPTION Azure Automation Workflow Runbook Script to stop or start all Virtual Machine Scale Sets in the current subscription or in a specific Resource Group. Useful for dev and test environments. Written to be used as either a scheduled job at the close of business or ad hoc when a VMSS is finished with for the moment. Requires an Azure Automation account with an Azure Run As account credential.

.VERSION 1.0.2

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

#>

<#
.SYNOPSIS
Stop or start all Virtual Machine Scale Sets in the current subscription or in a specific Resource Group

.PARAMETER ResourceGroupName
The Azure resource group name or leave empty to target ALL VMSS in the current subscription

.PARAMETER Action
Specify either 'stop' or 'start' to stop or start the VMSS.
#>
workflow StopStartVMSS
{
    Param
    (
        [Parameter(Mandatory=$false)] [String] $AzureResourceGroup,
	    [Parameter(Mandatory=$true)] [ValidateSet("Start","Stop")] [String]	$Action
    )

    $connectionName = "AzureRunAsConnection"
    try {
        Write-Output "Get the connection 'AzureRunAsConnection'"
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName

        "Logging in to Azure..."
        Add-AzureRmAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    } catch {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."
            throw $ErrorMessage
        } else{
            Write-Error -Message $_.Exception
            throw $_.Exception
        }
    }

    if ( $AzureResourceGroup ) {
        if ( $Action -eq "Stop")
        {
            Write-Output "Stopping VMSS in '$($AzureResourceGroup)' resource group";
            foreach -parallel ($name in (Get-AzureRmVmss -ResourceGroupName $AzureResourceGroup).Name)
            {
                Write-Output "Stopping VMSS '$($name)'";
                Stop-AzureRmVmss -ResourceGroupName $AzureResourceGroup -VMScaleSetName $name -Force -Verbose
            }
        }
        else
        {
            Write-Output "Starting VMSS in '$($AzureResourceGroup)' resource group";
            foreach -parallel ($name in (Get-AzureRmVmss -ResourceGroupName $AzureResourceGroup).Name)
            {
                Write-Output "Starting VMSS '$($name)'";
                Start-AzureRmVmss -ResourceGroupName $AzureResourceGroup -VMScaleSetName $name -Verbose
            }
        }
    } else {
        if ( $Action -eq "Stop")
        {
            Write-Output "Stopping all VMSS";
            foreach -parallel ($vmss in Get-AzureRmVmss)
            {
                Write-Output "Stopping VMSS '$($vmss.name)' in resource group '$($vmss.ResourceGroupName)'";
                Stop-AzureRmVmss -ResourceGroupName $vmss.ResourceGroupName -VMScaleSetName $vmss.name -Force -Verbose
            }
        }
        else
        {
            Write-Output "Starting all VMSS";
            foreach -parallel ($vmss in Get-AzureRmVmss)
            {
                Write-Output "Starting VMSS '$($vmss.name)' in resource group '$($vmss.ResourceGroupName)'";
                Start-AzureRmVmss -ResourceGroupName $vmss.ResourceGroupName -VMScaleSetName $vmss.name -Verbose
            }
        }

    }
}