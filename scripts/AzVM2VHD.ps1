<# Create a VHD from a managed disk VM #>
try {
    $Location = "Australia East"

    #Provide the subscription Id where the snapshot is created
    $subscriptionId='739c4e86-bd75-4910-8d6e-d7eb23ab94f3'

    #Provide the name of your resource group where the snapshot is created
    $resourceGroupName='BakingDP'
    $resourceGroupName_VM='BakingJPN'

    $vmName = '19srvjpnvm2'

    #Provide the snapshot name
    $snapshotName='w19-jpn-base2'

    #Provide Shared Access Signature (SAS) expiry duration in seconds (such as 3600)
    #Know more about SAS here: https://docs.microsoft.com/azure/storage/storage-dotnet-shared-access-signature-part-1
    # Allow access for 10 minutes. Need to expire relatively quickly so that a second copy may occur within 10 minutes because the removal of the snapshot will fail whilst the token is still valid and there seems no way to remove the token.
    $sasExpiryDuration=600

    #Provide storage account name where you want to copy the underlying VHD file. Currently, only general purpose v1 storage is supported.
    $storageAccountName='stagingdpauseast'

    #Name of the storage container where the downloaded VHD will be stored.
    $storageContainerName='vhds'

    #Provide the key of the storage account where you want to copy the VHD
    $key = Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -AccountName $storageAccountName | Where-Object {$_.KeyName -eq "key1"}
    $storageAccountKey = $key.value

    #Give a name to the destination VHD file to which the VHD will be copied.
    $destinationVHDFileName="$($snapshotName)2.vhd"

    Write-Host "Create a snapshot of the OS (and optionally data disks) from the generalized VM"
    $vm = Get-AzVM -ResourceGroupName $resourceGroupName_VM -Name $vmName
    $disk = Get-AzDisk -ResourceGroupName $resourceGroupName_VM -DiskName $vm.StorageProfile.OsDisk.Name
    $snapshot = New-AzSnapshotConfig -SourceUri $disk.Id -CreateOption Copy -Location $Location

    Revoke-AzSnapshotAccess -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName
    Get-AzSnapshot -ResourceGroupName $resourceGroupName -SnapshotName $snapshotName | Remove-AzSnapshot -Force
    New-AzSnapshot -ResourceGroupName $resourceGroupName -Snapshot $snapshot -SnapshotName $snapshotName

    az account set --subscription $subscriptionId


    Write-Host "Obtaining Snapshot SAS uri..."
    $sas = $(az snapshot grant-access --resource-group $resourceGroupName --name $snapshotName --duration-in-seconds $sasExpiryDuration --query [accessSas] -o tsv)

    Write-Host "Creating VHD from Snapshot..."
    $Options = @("storage", "blob", "copy", "start", "--destination-blob", $destinationVHDFileName, "--destination-container", $storageContainerName, "--account-name", $storageAccountName, "--account-key", $storageAccountKey, "--source-uri", """$sas""")
    &az $options
} catch {
    $_
}