#region Setup Powershell for AWS

# Set Powershell Script Execution Policy to RemoteSigned

Set-ExecutionPolicy -Scope CurrentUser RemoteSigned

# Import Powershell Module for Amazon Web Services before running this script
# Download from http://aws.amazon.com/powershell

Import-Module AWSPowershell

# Set AWS Access Key and Secret Key credentials
# Create and confirm at https://portal.aws.amazon.com.gp.aws/securityCredentials

Set-AWSCredentials -AccessKey AKIAIERYBE7AYSHDVUGA -SecretKey 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

#endregion Setup Powershell for AWS

#region onlocal Hyper-V Host

# Download VHD to local Hyper-V Host

$vhdTempPath = "c:\anthony\VMTemp\au1.vhd"

Copy-S3Object -BucketName lansavhdupload -Key AU1VM1 -localfile $vhdTempPath

# Convert Dynamically Expanding VHD to Fixed Size VHD

$vhdConvertedPath = "c:\anthony\VM\au1.vhd"

Convert-VHD -Path $vhdTempPath -DestinationPath $vhdConvertedPath -VHDType Fixed

# Install Hyper-V Integration Services

$cabPath = "c:\Windows\vmguest\support\amd64\Windows6.2-HyperVIntegrationServices-x64.cab"

$diskNum = (Mount-VHD -Path $vhdConvertedPath -PassThru).DiskNumber
(Get-Disk $diskNum).OperationalStatus
$vhdDriveLetter = (Get-Disk $diskNum | Get-Partition | Get-Volume).DriveLetter
Set-Disk $diskNum -IsReadOnly $False
Add-WindowsPackage -PackagePath $cabPath -Path ($vhdDriveLetter+":\")
#Add-WindowsPackage -PackagePath $cabPath -Path ("g:\")
Dismount-VHD -Path $vhdConvertedPath

#endregion

#region Upload To Azure

# Upload VHD and Provision VM in Windows Azure

# Set the Windows Azure Variable Values

$myStorageAcct = "portalvhds466j4jtfwwzxh"
$mySourceVHD = $vhdConvertedPath   # Local VHD Path to Upload From
$myDestVHD = "http://" + $myStorageAcct + ".blob.core.windows.net/vhds/au1.vhd"  #Windows Azure Storage Path to Upload
$myVMName = "vmFromAws"  # Windows Azure VM Name
$myCloudService = "vmFromAws-svc"  # Windows Azure Cloud Service Name

# Logon to Azure

Import-AzurePublishSettingsFile "c:\Azure\logon.publishsettings"

# Upload VHD to Azure Storage Account

Add-AzureVhd -LocalFilePath $mySourceVHD -Destination $myDestVHD

# Assign VHD t Azure Disk

Add-AzureDisk -OS Windows -MediaLocation $myDestVHD -DiskName "$myVMName-VHD"  # Add Disk for 1 VM

#endregion
