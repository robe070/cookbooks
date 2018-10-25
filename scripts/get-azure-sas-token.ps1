<#
.SYNOPSIS

Generate a SAS token for an Azure Image

.DESCRIPTION

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$false)]
    [string]
    $ImageName = 'IDESQL171image',
    [string]
    $StorageAccountName = 'lansalpcmsdn'
)

try {
    $NewImage = @(Get-AzureVMImage -ImageName "$ImageName")

    Write-Host "MediaLink = $($NewImage[0].OSDiskConfiguration.MediaLink)"

    $split = @($($NewImage[0].OSDiskConfiguration.MediaLink) -split  "/")
    $ContainerName = $split[3]

    if ( $split.Count -ne 5) {
        throw "Path to vhd contains more or less elements than code is expecting. The container part of the name probably consists of multiple folders, not just 'vhds'. This is the expected format: https://lansalpcmsdn.blob.core.windows.net/vhds/SCALE-CA1image-os-2016-08-19-3D9DF9B5.vhd"
    }
    Write-Host "ContainerName = $ContainerName (usually 'vhds')"

    #create the sas token
    $startTime = Get-Date
    $endTime = $startTime.AddDays(30)
    $startTime = $startTime.AddDays(-1)

    # azure_image_storage_key can be found using Azure Resource Explorer and using "Edit Connection Details" on the storage account name
    $StorageAccountKey = (Get-AzureStorageKey -StorageAccountName $StorageAccountName).primary
    $Context = New-AzureStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey
    $token = New-AzureStorageContainerSASToken -Name $ContainerName -Context $Context -Permission rl -ExpiryTime $endTime -StartTime $startTime

    Write-Host "Full url for Azure Publishing: $($NewImage[0].OSDiskConfiguration.MediaLink)$token"
}
catch {
    $_ | Write-Host
    Write-Host "Error. SAS token not produced"
}
