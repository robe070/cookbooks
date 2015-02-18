# Set Powershell Script Execution Policy to RemoteSigned

Set-ExecutionPolicy RemoteSigned

# Import Powershell Module for Amazon Web Services
# Download from http://aws.amazon.com/powershell

Import-Module AWSPowershell

# Set AWS Access Key and Secret Key credentials
# Create and confirm at https://portal.aws.amazon.com.gp.aws/securityCredentials

Set-AWSCredentials -AccessKey AKIAIERYBE7AYSHDVUGA -SecretKey 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

# Upload VHD to new Amazon S3 Bucket

Write-S3Object -BucketName lansavhdupload -File C:\VhdImages\AU1.vhd -Key AU1VM1 -CannedACLName Private -Region ap-southeast-2
