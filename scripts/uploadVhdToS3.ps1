# Set Powershell Script Execution Policy to RemoteSigned

Set-ExecutionPolicy Unrestricted -Scope CurrentUser

# Import Powershell Module for Amazon Web Services
# Download from http://aws.amazon.com/powershell

Import-Module AWSPowershell

# Set AWS Access Key and Secret Key credentials
# Create and confirm at https://portal.aws.amazon.com.gp.aws/securityCredentials

Set-AWSCredentials -AccessKey xxx -SecretKey xxx

# Upload VHD to new Amazon S3 Bucket

Write-S3Object -BucketName lansavhdupload -File C:\ImageForAzure.vhd -Key AUVM6 -CannedACLName Private -Region ap-southeast-2

Set-ExecutionPolicy Restricted -Scope CurrentUser
