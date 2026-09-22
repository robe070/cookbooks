# PowerShell script to obtain temporary AWS credentials for IAM user with MFA
# Prerequisites: Install AWS Tools for PowerShell (Install-Module -Name AWS.Tools.Common, AWS.Tools.SecurityToken)

$ErrorActionPreference = "Stop"

Write-Host "Ensure there are no existing AWS credentials set for this session..."
Clear-AWSCredential

$accountId = "775488040364"
$mfaDeviceName = "MicrosoftAuthenticator"
$mfaSerial = "arn:aws:iam::${accountId}:mfa/${mfaDeviceName}"

# Prompt for MFA token code (6 digits from your MFA device)
$tokenCode = Read-Host "Enter MFA token code"

# Get temporary session credentials (default duration: 1 hour; max 12 hours for GetSessionToken)
$tempCreds = Get-STSSessionToken -DurationInSeconds 43200 -SerialNumber $mfaSerial -TokenCode $tokenCode

# Set as default credentials for the current PowerShell session, AND persist them to the 'mfa'
# profile so a NEW session can pick them up with -ProfileName mfa.
#
# Why persisting matters: without -StoreAs these credentials exist only inside this process, so
# every script needing AWS has to be run in this same long-lived session. That session also holds
# the AWS.Tools DLLs open - .NET cannot unload an assembly - which makes it impossible to clean up
# superseded module versions during an upgrade. The half-deleted version folders that result (all
# the manifests gone, the locked DLLs left behind) then break that session's imports. Storing the
# profile breaks the dependency: run AWS work in a fresh shell, upgrade modules from anywhere.
#
# The stored item is a temporary SESSION token, not the long-lived IAM secret, it expires with the
# duration above, and on Windows the SDK credential store is DPAPI-encrypted for this user only.
Set-AWSCredential `
    -AccessKey $tempCreds.AccessKeyId `
    -SecretKey $tempCreds.SecretAccessKey `
    -SessionToken $tempCreds.SessionToken `
    -StoreAs mfa

# -StoreAs writes the profile but does not make it this session's default, so set it as well.
Set-AWSCredential -ProfileName mfa

Write-Host "Temporary MFA-protected credentials set for session (expires: $($tempCreds.Expiration))"
Write-Host "Also saved as the 'mfa' profile - fresh sessions can use: -ProfileName mfa"