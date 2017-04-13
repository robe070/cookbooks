<#
.SYNOPSIS

Generate a SAS token for an Azure Image

.DESCRIPTION

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$false)]
    [string]
    $ImageName = 'SCALE-CA1image'
)

try {
    $NewImage = @(Get-AzureVMImage -ImageName "$ImageName")

    Write-Output "MediaLink = $($NewImage[0].OSDiskConfiguration.MediaLink)"

    $split = @($($NewImage[0].OSDiskConfiguration.MediaLink) -split  "/")
    $ContainerName = $split[3]

    if ( $split.Count -ne 5) {
        Write-Error "Path to vhd contains more or less elements than code is expecting. The container part of the name probably consists of multiple folders, not just 'vhds'. This is the expected format: https://lansalpcmsdn.blob.core.windows.net/vhds/SCALE-CA1image-os-2016-08-19-3D9DF9B5.vhd"
        return
    }
    Write-Output "ContainerName = $ContainerName (usually 'vhds')"

    #create the sas token
    $startTime = Get-Date
    $endTime = $startTime.AddDays(30)
    $startTime = $startTime.AddDays(-1)
    $token = New-AzureStorageContainerSASToken -Name $ContainerName -Permission rl -ExpiryTime $endTime -StartTime $startTime

    Write-Output "Full url for Azure Publishing: $($NewImage[0].OSDiskConfiguration.MediaLink)$token"
}
catch {
    Write-Output "Error. SAS token not produced"
}
