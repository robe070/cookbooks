<#
.SYNOPSIS
Add a managed image to an Azure Compute Gallery.

.DESCRIPTION
This script adds a managed image to an Azure Compute Gallery, creating the gallery and image definition if they do not exist, and then creating an image version from the managed image.
It then calls get-azure-sas-token.ps1 to configure access for Azure Marketplace submission.

.EXAMPLE
.\add-to-azure-compute-gallery.ps1
# Uses defaults: ResourceGroupName="BakingDP", Location="Australia East", ImageName="w16d-16-0-0image", VersionText="16.0.0"

.EXAMPLE
.\add-to-azure-compute-gallery.ps1 -ImageName "w16d-16-0-0image" -VersionText "16.0.0" -ImageDefinitionName "VL-w16d-16-0" -SKU "w16d-16-0"
# Uses provided parameters explicitly
#>

param (
    [Parameter()]
    [string]$ResourceGroupName = "BakingDP",

    [Parameter()]
    [string]$Location = "Australia East",

    [Parameter()]
    [string]$ImageName = "w16d-16-0-0image",  # Managed image name, e.g., "w16d-16-0-0image"

    [Parameter()]
    [string]$VersionText = "16.0.0",  # Version, e.g., "16.0.0"

    [Parameter()]
    [string]$GalleryName = "LansaGallery",

    [Parameter()]
    [string]$Publisher = "LANSA",

    [Parameter()]
    [string]$Offer = "lansa-scalable-license",

    [Parameter()]
    [string]$SKU = "w16d-16-0",  # SKU, e.g., "w16d-16-0"

    [Parameter()]
    [string]$ImageDefinitionName = "VL-w16d-16-0",  # Image definition name, e.g., "VL-w16d-16-0"

    [Parameter()]
    [string]$GetAzureSasTokenPath = "c:\lansa\scripts\get-azure-sas-token.ps1",  # Literal path from bake-IdeMsi.ps1

    [Parameter()]
    [string]$StorageAccountName = "",

    [Parameter()]
    [string]$StorageAccountResourceGroup = ""
)

#Requires -RunAsAdministrator
#Requires -Modules Az.Compute

try {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Adding image $ImageName to Azure Compute Gallery $GalleryName in resource group $ResourceGroupName"

    # Get the managed image
    $image = Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName $ImageName -ErrorAction Stop
    if (-not $image) {
        throw "Managed image $ImageName not found in resource group $ResourceGroupName"
    }

    # Create or get the gallery
    $gallery = Get-AzGallery -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -ErrorAction SilentlyContinue
    if (-not $gallery) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Creating new gallery $GalleryName in $ResourceGroupName..."
        $gallery = New-AzGallery -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -Location $Location -ErrorAction Stop
    }

    # Create or update image definition
    $imageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $ImageDefinitionName -ErrorAction SilentlyContinue
    if (-not $imageDefinition) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Creating image definition $ImageDefinitionName..."
        $imageDefinitionParams = @{
            ResourceGroupName          = $ResourceGroupName
            GalleryName                = $GalleryName
            GalleryImageDefinitionName = $ImageDefinitionName
            Location                   = $Location
            OsType                     = 'Windows'
            OsState                    = 'Generalized'
            Publisher                  = $Publisher
            Offer                      = $Offer
            Sku                        = $SKU
            HyperVGeneration           = 'V1'  # Adjust to 'V1' if needed for older images
        }
        $imageDefinition = New-AzGalleryImageDefinition @imageDefinitionParams -ErrorAction Stop
    }

    # Create image version
    $galleryImageVersion = $VersionText.Replace("-", ".")  # Ensure version format like "16.0.0"
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Creating image version $galleryImageVersion..."
    $region = @{Name = $Location; ReplicaCount = 1}
    $imageVersionParams = @{
        ResourceGroupName          = $ResourceGroupName
        GalleryName                = $GalleryName
        GalleryImageDefinitionName = $ImageDefinitionName
        GalleryImageVersionName    = $galleryImageVersion
        Location                   = $Location
        SourceImageId              = $image.Id
        TargetRegion               = @($region)
    }
    $imageVersion = New-AzGalleryImageVersion @imageVersionParams -ErrorAction Stop

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Image version $galleryImageVersion created in gallery $GalleryName with Resource ID: $($imageVersion.Id)"

    # Call get-azure-sas-token.ps1
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') Calling get-azure-sas-token.ps1 for access configuration..."
    & $GetAzureSasTokenPath -ResourceGroupName $ResourceGroupName -ImageName $ImageDefinitionName -StorageAccountName $StorageAccountName -StorageAccountResourceGroup $StorageAccountResourceGroup -GalleryName $GalleryName -GalleryImageVersion $galleryImageVersion | Out-Default

} catch {
    Write-Error "Error adding image to Azure Compute Gallery: $_"
    throw
}