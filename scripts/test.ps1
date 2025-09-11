<#
.SYNOPSIS
Add a managed image to an Azure Compute Gallery.

.DESCRIPTION
This script adds a managed image to an Azure Compute Gallery, creating the gallery and image definition if they do not exist, and then creating an image version from the managed image.
If the image version already exists, it is deleted and recreated. It then calls get-azure-sas-token.ps1 to configure access for Azure Marketplace submission.

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
    [string]$ImageName = "w22d-16-0-0image",  # Managed image name, e.g., "w16d-16-0-0image"

    [Parameter()]
    [string]$VersionText = "16.0.0",  # Version, e.g., "16.0.0"

    [Parameter()]
    [string]$GetAzureSasTokenPath = "c:\lansa\scripts\get-azure-sas-token.ps1",  # Updated default path

    [Parameter()]
    [string]$StorageAccountName = "",

    [Parameter()]
    [string]$StorageAccountResourceGroup = ""
)

function Log-Date
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

#Requires -RunAsAdministrator
#Requires -Modules Az.Compute
$VmResourceGroup = "BakingDP-w22d-16-0-0"
$Script:vmname = "w22d-16-0-0"
try {
       Write-Host "$(Log-Date) Creating Managed Image..."
        $vm = Get-AzVM -ResourceGroupName $VmResourceGroup -Name $Script:vmname -ErrorAction Stop
        # $imageConfig = New-AzImageConfig -Location $Location -SourceVirtualMachineId $vm.Id -HyperVGeneration V2
        # $image = New-AzImage -ResourceGroupName $ImageResourceGroup -Image $imageConfig -ImageName $ImageName | Out-Default | Write-Host

        # Add image to Azure Compute Gallery
        $GalleryName = "LansaGallery"
        $ImageDefinitionName = $ImageName -replace "-\d+image$", "" # "w16d-16-0-19image" => "w16d-16-0"
        $versionNumbers = $VersionText -split '-' | Select-Object -Last 3
        $galleryImageVersion = $versionNumbers -join '.' # Ensure version format like "16.0.19"
        Write-Host "$(Log-Date) Adding image $ImageName to Azure Compute Gallery $GalleryName in resource group $ResourceGroupName"

        # # Get the managed image
        # $image = Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName $ImageName -ErrorAction Stop
        # if (-not $image) {
        #     throw "Managed image $ImageName not found in resource group $ResourceGroupName"
        # }

        # Create or get the gallery
        $gallery = Get-AzGallery -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -ErrorAction SilentlyContinue
        if (-not $gallery) {
            Write-Host "$(Log-Date) Creating new gallery $GalleryName in $ResourceGroupName..."
            $gallery = New-AzGallery -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -Location $Location -ErrorAction Stop
        }

        # Create or update image definition
        $imageDefinition = Get-AzGalleryImageDefinition -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $ImageDefinitionName -ErrorAction SilentlyContinue
        if (-not $imageDefinition) {
            Write-Host "$(Log-Date) Creating image definition $ImageDefinitionName..."
            $imageDefinitionParams = @{
                ResourceGroupName          = $ResourceGroupName
                GalleryName                = $GalleryName
                GalleryImageDefinitionName = $ImageDefinitionName
                Location                   = $Location
                OsType                     = 'Windows'
                OsState                    = 'Generalized'
                Publisher                  = 'LANSA'
                Offer                      = 'lansa-scalable-license'
                Sku                        = $ImageDefinitionName
                HyperVGeneration           = 'V2'
                Feature                    = @(@{Name='SecurityType';Value='TrustedLaunch'})
            }
            $imageDefinition = New-AzGalleryImageDefinition @imageDefinitionParams -ErrorAction Stop
        }

        # Check for existing image version and delete if it exists
        $existingVersion = Get-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $ImageDefinitionName -GalleryImageVersionName $galleryImageVersion -ErrorAction SilentlyContinue
        if ($existingVersion) {
            Write-Host "$(Log-Date) Image version $galleryImageVersion already exists. Deleting..."
            Remove-AzGalleryImageVersion -ResourceGroupName $ResourceGroupName -GalleryName $GalleryName -GalleryImageDefinitionName $ImageDefinitionName -GalleryImageVersionName $galleryImageVersion -Force -ErrorAction Stop
        }

        # Create image version directly from generalised VM - because cannot create a managed image with TrustedLaunch SecurityType.
        Write-Host "$(Log-Date) Creating image version $galleryImageVersion..."
        $region = @{Name = $Location; ReplicaCount = 1}
        $imageVersionParams = @{
            ResourceGroupName          = $ResourceGroupName
            GalleryName                = $GalleryName
            GalleryImageDefinitionName = $ImageDefinitionName
            GalleryImageVersionName    = $galleryImageVersion
            Location                   = $Location
            SourceImageId            = '/subscriptions/739c4e86-bd75-4910-8d6e-d7eb23ab94f3/resourceGroups/BakingDP-w22d-16-0-0/providers/Microsoft.Compute/virtualMachines/w22d-16-0-0'
            TargetRegion               = @($region)  # Updated to use TargetRegion
        }
        $imageVersion = New-AzGalleryImageVersion @imageVersionParams -ErrorAction Stop

        Write-Host "$(Log-Date) Image version $galleryImageVersion created in gallery $GalleryName with Resource ID: $($imageVersion.Id)"

} catch {
    Write-Error "Error adding image to Azure Compute Gallery: $_"
    throw
}