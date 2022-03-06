########################################################################
# PARAMETERS:
#  0. Fully qualified path to license file
#  1. Certificate password
#  2. DNS Name
#  3. Private Key registry value name
########################################################################
param (
    [string[]]  $VMList = ('win11'),
    [string[]]  $vmSecrets =  'DevelopmentLicensePrivateKey'
)
#Requires -RunAsAdministrator

#Set-StrictMode -Version Latest

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir) {
    # Log-Date can't be used yet as Framework has not been loaded

    Write-Host "Initialising environment - presumed not running through RemotePS"
    $MyInvocation.MyCommand.Path
    $script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

    . "$script:IncludeDir\Init-Baking-Vars.ps1"
    . "$script:IncludeDir\Init-Baking-Includes.ps1"
} else {
    Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

# Gets the secrets  from Azure Vault
$KeyVault = "bakingVaultDP"
$KeyVaultResourceGroup = "BakingDP"
$sourceVaultId = (Get-AzKeyVault -ResourceGroupName $KeyVaultResourceGroup -VaultName $KeyVault).ResourceId

# $vmSecrets = @("DevelopmentLicensePrivateKey");
$vmSecretUrls = @();
foreach ($vmCertificateName in $vmSecrets) {
    $secret = Get-AzKeyVaultSecret -VaultName $KeyVault -Name $vmCertificateName
    if ( $secret ) {
        # Write to a file
        Write-Host "$(Log-Date) Found the secret for $vmCertificateName Certificate"
        $vmSecretUrls += $secret.id;
    } else {
        throw 'Certificate $vmCertificateName not found in the Key Vault $KeyVault'
    }
}

foreach ($vm in $vmlist ) {
    $vm1 = Get-AzVM -Name $vm
    foreach ($vmSecret in $vmSecretUrls) {
        $vm1 = Add-AzVMSecret -VM $vm1 -SourceVaultId $sourceVaultId -CertificateStore 'My' -CertificateUrl $vmSecret
    }
    Update-AzVM -ResourceGroup $vm1.ResourceGroupName -VM $vm1
}
