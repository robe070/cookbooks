<#
.SYNOPSIS
Generate a SAS URI for an Azure Managed Image for Marketplace submission.

.DESCRIPTION
This script generates a SAS URI for a managed image in Azure, suitable for submission to the Azure Marketplace.
It uses the Grant-AzImageAccess cmdlet to provide temporary read access to the image.

.EXAMPLE
.\get-azure-sas-token.ps1 -ResourceGroupName "BakingDP" -ImageName "w19image" -StorageAccountName "stagingdpauseast" -StorageAccountResourceGroup "BakingDP"
#>

param (
    [Parameter(Mandatory=$true)]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]
    $ImageName,

    [Parameter(Mandatory=$false)]
    [string]
    $StorageAccountName, # Not used for managed disks but retained for compatibility

    [Parameter(Mandatory=$false)]
    [string]
    $StorageAccountResourceGroup # Not used for managed disks but retained for compatibility
)

#Requires -RunAsAdministrator
#Requires -Modules Az.Compute

try {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Generating SAS URI for managed image $ImageName in resource group $ResourceGroupName"

    # Get the managed image
    $NewImage = Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName $ImageName -ErrorAction Stop
    if (-not $NewImage) {
        throw "Image $ImageName not found in resource group $ResourceGroupName"
    }

    # Generate SAS URI with 30-day expiry (adjust as needed for Marketplace)
    $startTime = (Get-Date).AddDays(-1)
    $endTime = $startTime.AddDays(30)
    $sasUri = Grant-AzImageAccess -ResourceGroupName $ResourceGroupName -ImageName $ImageName -AccessLevel Read -DurationInSeconds (30 * 24 * 3600) -ErrorAction Stop

    # Pipeline output for Azure DevOps compatibility
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$sasUri"

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Full SAS URI for Azure Publishing: $sasUri"
    return $sasUri
} catch {
    Write-Error "Error generating SAS URI: $_"
    throw "Error. SAS URI not produced"
}