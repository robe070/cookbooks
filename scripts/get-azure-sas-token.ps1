<#
.SYNOPSIS

Generate a SAS token for an Azure Image

.DESCRIPTION

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$true)]
    [string]
    $ResourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]
    $ImageName,

    [Parameter(Mandatory=$true)]
    [string]
    $storageAccountName,

    [Parameter(Mandatory=$false)]
    [string]
    $StorageResourceGroupName
)

try {
    if (!$StorageResourceGroupName) {
        $StorageResourceGroupName = $ResourceGroupName
    }
    $NewImage = @(Get-AzImage -ResourceGroupName $ResourceGroupName -ImageName "$ImageName")
    # This is what we need to work with...
    # $NewImage[0].StorageProfile.OsDisk.ManagedDisk.id
    # "/subscriptions/edff5157-5735-4ceb-af94-526e2c235e80/resourceGroups/bakingMSDN/providers/Microsoft.Compute/disks/SCALE-CA4_OsDisk_1_54355c013d6345138e77b87f3b37d6a5"
    $uri = $NewImage[0].StorageProfile.OsDisk.BlobUri
    Write-Host "Uri = $uri"

    $split = @($Uri -split  "/")
    $ContainerName = $split[3]

    Write-Host "ContainerName = $ContainerName (usually 'vhds')"

    if ( $split.Count -ne 5) {
        Write-Error "Path to vhd contains more or less elements than code is expecting. The container part of the name probably consists of multiple folders, not just 'vhds'. This is the expected format: https://lansalpcmsdn.blob.core.windows.net/vhds/SCALE-CA1image-os-2016-08-19-3D9DF9B5.vhd"
        return
    }

    # create the sas token
    $accountKeys = Get-AzStorageAccountKey -ResourceGroupName $StorageResourceGroupName -Name $storageAccountName
    $storageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $accountKeys[0].Value

    $startTime = Get-Date
    $endTime = $startTime.AddDays(30)
    $startTime = $startTime.AddDays(-1)
    $token = New-AzStorageContainerSASToken -Context $storageContext -Name $ContainerName -Permission rl -ExpiryTime $endTime -StartTime $startTime

    Write-Host "Full url for Azure Publishing: $uri$token"
} catch {
    $_ | Out-default | Write-Host
    throw "Error. SAS token not produced"
}
