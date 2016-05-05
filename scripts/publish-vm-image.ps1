# Assume that source vm has been properly syspreped (or waagent -deprovision), and then the image has been captured
# The image name = "prlinvmtwaatimg1", the VHD name = "1y4u2qcb.3ak201305280317090939.vhd" and is in storage 
# account stgactprvnteastus1, thus, the uri = "http://stgactprvnteastus1.blob.core.windows.net/vhds/1y4u2qcb.3ak201305280317090939.vhd"
# Note that the vhd file is in "vhds" container not "images". That is because, the Portal UI does not give an option to output
# the image in a different location, nor does it allow the naming of the vhd file. However, all new images that we will create
# will be named using our naming convention, and will be placed in "images" container of the destination storage account

# Subscription
$SubscriptionName="Main";
$SubscriptionID="84a7edff-6835-4389-977f-da323848e89e";

# Storage (specify your storage account names)
$SrcStorageAccount="lansalpcmsdn";
$DestStorageAccount="lansalpc";

$ImageContainerName="images";
$VHDContainerName="vhds";

# Find out the actual name of the VHD by looking in your storage account/container
$SrcImageVHD="IDESQL-D3image-os-2016-04-19-7967BD0A.vhd";
$SrcImageName="IDESQL-D3image";

# Give some names to the image and the vhd file based on your naming convention
$DestImageVHD="IDESQL-D3image-os-2016-04-19-7967BD0A.vhd";
$DestImageName="IDESQL-D3image";


#VNet (for testing purpose, pick a VNet where you want to add a new VM using this image)
$VNetName="VNetPRVNT";
$SubnetName="Subnet-1";
$AffinityGroupName="AGPRVNTEastUS1";


# Pick the current subscription
Select-AzureSubscription -SubscriptionName $SubscriptionName;

# Context to source storage
$SrcStgKey = (Get-AzureStorageKey -StorageAccountName $SrcStorageAccount).Primary;
$SrcStorageContext=New-AzureStorageContext -StorageAccountName $SrcStorageAccount -StorageAccountKey $SrcStgKey -Protocol Https;

# Context to destination storage
$DestStgKey = (Get-AzureStorageKey -StorageAccountName $DestStorageAccount).Primary;
$DestStorageContext=New-AzureStorageContext -StorageAccountName $DestStorageAccount -StorageAccountKey $DestStgKey -Protocol Https;



# Copy image blob from source storage to dest storage; note that initial image blob is 
# in "vhds" container not "images", even though going forward, we want to use "images"
$ImageBlob=Start-CopyAzureStorageBlob 
    -SrcContext $SrcStorageContext -SrcBlob $SrcImageVHD -SrcContainer $VHDContainerName 
    -DestContext $DestStorageContext -DestContainer $ImageContainerName -DestBlob $DestImageVHD;


# Wait for copy to complete
$ImageBlob | Get-AzureStorageBlobCopyState -WaitForComplete;


# Create image out of the copied blob
# The newly created image will be physically located in the "images" container using the MediaLocation parameter
$DestImageURI = "https://$DestStorageAccount.blob.core.windows.net/$ImageContainerName/$DestImageVHD";

Add-AzureVMImage -ImageName $DestImageName -OS "Windows" -MediaLocation  $DestImageURI -Label "IDESQL-D3image-os-2016-04-19-7967";



# Create a VM using the image just created
$VMName="PRVMTLinStg2VNT1";
$ServiceName="PRVNTLinSvc1";
$MediaLocation="http://$DestStorageAccount.blob.core.windows.net/$VHDContainerName/$VMName.vhd";

# The newly created VM will be placed in the "vhds" container as instructed via the MediaLocation parameter
New-AzureVMConfig -Name $VMName -ImageName $DestImageName -InstanceSize "Small" -MediaLocation $MediaLocation | 
    Add-AzureProvisioningConfig -Linux -LinuxUser "azureuser" -Password "Some password" -NoSSHEndpoint |
    Add-AzureEndpoint -Name 'TLSSH' -Protocol 'TCP' -LocalPort 22 -PublicPort 22 |
    Set-AzureSubnet -SubnetNames $SubnetName | 
    New-AzureVM -ServiceName $ServiceName -VNetName $VNetName -AffinityGroup $AffinityGroupName;






