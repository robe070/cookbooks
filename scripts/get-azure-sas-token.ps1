<#
.SYNOPSIS
Generate access for an Azure Compute Gallery image version or managed image for Marketplace submission using RBAC.

.DESCRIPTION
This script grants read access to a gallery image version or managed image for Azure Marketplace submission by assigning the Compute Gallery Image Reader role to Microsoft's ingestion service principals.
Optionally, it can export the image to a VHD and generate a SAS URI if required.

.EXAMPLE
.\get-azure-sas-token.ps1 -ResourceGroupName "BakingDP" -ImageName "w19image" -StorageAccountName "stagingdpauseast" -StorageAccountResourceGroup "BakingDP" -GalleryName "LansaGallery" -GalleryImageVersion "1.0.0"
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
    $StorageAccountName, # Not used for RBAC but retained for compatibility

    [Parameter(Mandatory=$false)]
    [string]
    $StorageAccountResourceGroup, # Not used for RBAC but retained for compatibility

    [Parameter(Mandatory=$false)]
    [string]
    $GalleryName="LansaGallery", # Optional for gallery image version

    [Parameter(Mandatory=$false)]
    [string]
    $GalleryImageVersion="16.0.0" # Optional for gallery image version
)

#Requires -RunAsAdministrator
#Requires -Modules Az.Compute

Write-Host("ResourceGroupName=$ResourceGroupName, ImageName=$ImageName, GalleryName=$GalleryName, GalleryImageVersion=$GalleryImageVersion" )

try {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Configuring access for image $ImageName in resource group $ResourceGroupName"

    # Use gallery image version if provided; otherwise, use managed image
    if ($GalleryName -and $GalleryImageVersion) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Retrieving gallery image version $GalleryImageVersion from gallery $GalleryName..."
        $imageVersion = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $ImageName -GalleryImageVersionName $GalleryImageVersion -ErrorAction Stop
        if (-not $imageVersion) {
            throw "Gallery image version $GalleryImageVersion not found in gallery $GalleryName"
        }
        $imageResourceId = $imageVersion.Id
        $roleDefinitionId = "cf7c76d2-98a3-4358-a134-615aa78bf44d" # Compute Gallery Image Reader
    } else {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Retrieving managed image $ImageName..."
        $image = Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName $ImageName -ErrorAction Stop
        if (-not $image) {
            throw "Image $ImageName not found in resource group $ResourceGroupName"
        }
        $imageResourceId = $image.Id
        $roleDefinitionId = "acdd72a7-3385-48ef-bd42-f606fba81ae7" # Reader role for managed images
    }

    # Microsoft's ingestion service principals for Compute Gallery
    $servicePrincipals = @(
        @{ Name = "Microsoft Partner Center Resource Provider"; ObjectId = $null },
        @{ Name = "Compute Image Registry"; ObjectId = $null }
    )

    # Find Object IDs for service principals
    foreach ($sp in $servicePrincipals) {
        $spObject = Get-AzADServicePrincipal -SearchString $sp.Name -ErrorAction SilentlyContinue
        if ($spObject) {
            $sp.ObjectId = $spObject.Id
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Found service principal $($sp.Name) with Object ID: $($sp.ObjectId)"
        } else {
            Write-Error "Service principal $($sp.Name) not found in your tenant. Contact Azure Marketplace support for the correct Object ID."
        }
    }

    # Assign the appropriate role to each service principal
    foreach ($sp in $servicePrincipals) {
        if ($sp.ObjectId) {
            Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Assigning role to service principal $($sp.Name) for image $ImageName"
            $roleAssignmentParams = @{
                ObjectId           = $sp.ObjectId
                RoleDefinitionId   = $roleDefinitionId
                Scope              = $imageResourceId
                ErrorAction        = 'SilentlyContinue' # Avoid errors if role is already assigned
            }
            New-AzRoleAssignment @roleAssignmentParams
            if ($?) {
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Successfully assigned role to $($sp.Name)"
            } else {
                Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Role assignment for $($sp.Name) already exists or failed."
            }
        }
    }

    # Output the Resource ID as ImageUrl for Azure DevOps compatibility
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$imageResourceId"
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Resource ID for Azure Marketplace: $imageResourceId"

    <#
    # Optional: Export image to VHD and generate SAS URI if required
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Exporting image to VHD for SAS URI generation (optional)..."
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $StorageAccountResourceGroup -Name $StorageAccountName -ErrorAction Stop
    $containerName = "vhds"
    $vhdBlobName = "$ImageName-$(Get-Date -Format 'yyyyMMddHHmmss').vhd"
    $vhdUri = "https://$StorageAccountName.blob.core.windows.net/$containerName/$vhdBlobName"

    # Ensure the container exists
    $context = $storageAccount.Context
    $container = Get-AzStorageContainer -Name $containerName -Context $context -ErrorAction SilentlyContinue
    if (-not $container) {
        New-AzStorageContainer -Name $containerName -Context $context -Permission Off -ErrorAction Stop
    }

    # Export the image to a VHD
    $sourceId = $GalleryName ? $imageVersion.Id : $image.Id
    $exportConfig = New-AzDiskExportConfig -SourceResourceId $sourceId -SasExpiryDuration 604800 -VhdUri $vhdUri
    Start-AzDiskExport -ResourceGroupName $ResourceGroupName -DiskName $ImageName -ExportConfig $exportConfig -Force -ErrorAction Stop

    # Generate SAS URI for the VHD
    $startTime = (Get-Date).AddDays(-1)
    $endTime = $startTime.AddDays(30)
    $sasToken = New-AzStorageBlobSASToken -Context $context -Container $containerName -Blob $vhdBlobName -Permission "r" -StartTime $startTime -ExpiryTime $endTime -ErrorAction Stop

    # Output the SAS URI
    $sasUri = "$vhdUri?$sasToken"
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$sasUri"
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') SAS URI for Azure Marketplace: $sasUri"
    #>

    return $imageResourceId
} catch {
    Write-Error "Error configuring access for image: $_"
    throw "Error. Access not configured for image $ImageName"
}