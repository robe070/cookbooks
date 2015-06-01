#region Setup Powershell for AWS

# Set Powershell Script Execution Policy to RemoteSigned

Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Import Powershell Module for Amazon Web Services before running this script
# Download from http://aws.amazon.com/powershell

Import-Module AWSPowershell

# Set AWS Access Key and Secret Key credentials
# Create and confirm at https://portal.aws.amazon.com.gp.aws/securityCredentials

Set-AWSCredentials -AccessKey xxx -SecretKey xxx

#endregion Setup Powershell for AWS

#region onlocal Hyper-V Host

# Download VHD to local Hyper-V Host

$vmName = "AUVM6"
$vhdTempPath = "c:\anthony\VMTemp\" + $vmName + ".vhd"
$vhdConvertedPath = "c:\anthony\VM\" + $vmName + ".vhd"

Copy-S3Object -BucketName lansavhdupload -Key $vmName -localfile $vhdTempPath

# Convert Dynamically Expanding VHD to Fixed Size VHD

Convert-VHD -Path $vhdTempPath -DestinationPath $vhdConvertedPath -VHDType Fixed

# Install Hyper-V Integration Services

$cabPath = "c:\Windows\vmguest\support\amd64\Windows6.2-HyperVIntegrationServices-x64.cab"

$diskNum = (Mount-VHD -Path $vhdConvertedPath -PassThru).DiskNumber
(Get-Disk $diskNum).OperationalStatus
$vhdDriveLetter = (Get-Disk $diskNum | Get-Partition | Get-Volume).DriveLetter
Set-Disk $diskNum -IsReadOnly $False
Add-WindowsPackage -PackagePath $cabPath -Path ($vhdDriveLetter[0]+":\")
#Add-WindowsPackage -PackagePath $cabPath -Path ("g:\")
Dismount-VHD -Path $vhdConvertedPath

#endregion

#region Upload To Azure

# Upload VHD and Provision VM in Windows Azure

# Set the Windows Azure Variable Values

$azureStorageAcct = "portalvhds466j4jtfwwzxh"
$azureSourceVHD = $vhdConvertedPath   # Local VHD Path to Upload From
$azureDestVHD = "https://" + $azureStorageAcct + ".blob.core.windows.net/vhds/"+ $vmName +".vhd"  #Windows Azure Storage Path to Upload
$azureVMName = $vmName + "FromAws"  # Windows Azure VM Name

# Logon to Azure

Import-AzurePublishSettingsFile "c:\Anthony\logon.publishsettings"

# Upload VHD to Azure Storage Account

Add-AzureVhd -LocalFilePath $azureSourceVHD -Destination $azureDestVHD

# Assign VHD to Azure Disk

Add-AzureDisk -OS Windows -MediaLocation $azureDestVHD -DiskName "$azureVMName"  # Add Disk for 1 VM

#endregion
