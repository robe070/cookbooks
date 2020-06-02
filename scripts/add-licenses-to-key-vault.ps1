$vaultName = "BakingVault1"
$resourceGroup = "BakingVault1"
$location = "australiaeast"


# $vaultName = "bakingVaultindia"
# $resourceGroup = "BakingMSDN-southindia"
# $location = "southindia"

# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
Get-AzContext
New-AzResourceGroup -ResourceGroupName $resourceGroup -Location $location  -Force
if ( -not (Get-AzKeyVault -ResourceGroupName $resourceGroup -VaultName $vaultName) ) {
    Write-Host ("Creating Key Vault...")
    New-AzKeyVault -VaultName $vaultName -ResourceGroupName $resourceGroup -Location $location -sku standard -EnabledForDeployment
}

[string[][]]$Keys = @( `
@("LANSA Scalable License", "ScalableLicensePrivateKey", "c:\temp\LANSAScalableLicense.pfx"), `
@("LANSA Integrator License", "IntegratorLicensePrivateKey", "c:\temp\LANSAIntegratorLicense.pfx"), `
@("LANSA Development License", "DevelopmentLicensePrivateKey", "c:\temp\LANSADevelopmentLicense.pfx") )

foreach ( $LicensePrivateKey in $Keys ) {
    $LicensePrivateKey[0]
    $LicensePrivateKey[1]
    $LicensePrivateKey[2]

    $fileContentBytes = Get-Content $LicensePrivateKey[2] -Encoding Byte
    $fileContentEncoded = [System.Convert]::ToBase64String($fileContentBytes)
    $jsonObject = @"
{
  "data": "$fileContentEncoded",
  "dataType" :"pfx",
  "password": "$ENV:cloud_license_key"
}
"@
    $jsonObjectBytes = [System.Text.Encoding]::UTF8.GetBytes($jsonObject)
    $jsonEncoded = [System.Convert]::ToBase64String($jsonObjectBytes)

    $secret = ConvertTo-SecureString -String $jsonEncoded -AsPlainText -Force
    $SecretKey = Set-AzKeyVaultSecret -VaultName $vaultName -Name $LicensePrivateKey[1] -SecretValue $secret
    $SecretKey
}
