# PowerShell script to obtain temporary AWS credentials for IAM user with MFA
# Prerequisites: Install AWS Tools for PowerShell (Install-Module -Name AWS.Tools.Common, AWS.Tools.SecurityToken)

$accountId = "775488040364"
$mfaDeviceName = "MicrosoftAuthenticator"
$mfaSerial = "arn:aws:iam::${accountId}:mfa/${mfaDeviceName}"

# Prompt for MFA token code (6 digits from your MFA device)
$tokenCode = Read-Host "Enter MFA token code"

# Get temporary session credentials (default duration: 1 hour; max 12 hours for GetSessionToken)
$tempCreds = Get-STSSessionToken -DurationInSeconds 43200 -SerialNumber $mfaSerial -TokenCode $tokenCode

# Set as default credentials for the current PowerShell session
Set-AWSCredential `
    -AccessKey $tempCreds.AccessKeyId `
    -SecretKey $tempCreds.SecretAccessKey `
    -SessionToken $tempCreds.SessionToken

Write-Host "Temporary MFA-protected credentials set for session (expires: $($tempCreds.Expiration))"