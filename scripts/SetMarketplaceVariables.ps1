# SetMarketplaceVariables.ps1
# This script sets Azure DevOps variables based on input parameters version and templateType.
# It dynamically retrieves template URLs from AWS Marketplace using Get-MCATEntity.

param (
    [Parameter(Mandatory=$true)]
    [string]$version,

    [Parameter(Mandatory=$true)]
    [ValidateSet('master', 'shoesize')]
    [string]$templateType
)

# Product mapping with live product IDs
# Note: this table is also in AWSTemplates/scripts/UpdateTemplatesInMarketplace.ps1
# Keep both copies in sync
$productMapping = @(
    @('w19d-15-0', 'prod-7c4xdvxkskdfs'),  # English
    @('w19d-15-0j', 'prod-csfkcd5qvncle'),   # Japanese
    @('w19d-16-0', 'prod-7c4xdvxkskdfs'),  # English
    @('w19d-16-0j', 'prod-csfkcd5qvncle'),   # Japanese

    @('w22d-15-0', 'prod-vmu3flp7pyc4a'),  # English
    @('w22d-15-0j', 'prod-uxdxgg354h7aq'),   # Japanese
    @('w22d-16-0', 'prod-vmu3flp7pyc4a'),  # English
    @('w22d-16-0j', 'prod-uxdxgg354h7aq'),   # Japanese

    @('w25d-15-0', 'prod-gquyjeiww36se'),  # English
    @('w25d-15-0j', 'prod-urhng7afyfwr6'),   # Japanese
    @('w25d-16-0', 'prod-gquyjeiww36se'),  # English
    @('w25d-16-0j', 'prod-urhng7afyfwr6')   # Japanese
)

# Function to derive key components from version
function Get-KeyComponents {
    param (
        [string]$Version
    )

    $parts = $Version.Split('-')
    $key1 = $parts[0]  # e.g., w19d
    $key2 = if ($Version -like '*j-*') { 'jpn' } else { 'eng' }
    $versionBase = $parts[1]  # e.g., 15
    $versionMinor = $parts[2].Replace('j', '')  # e.g., 0, removing 'j' if present
    $versionDigits = $parts[3]  # e.g., 19

    return $key1, $key2, $versionBase, $versionMinor, $versionDigits
}

try {
    # Set default region for Marketplace Catalog API
    Set-DefaultAWSRegion -Region 'us-east-1'

    # Get key components
    $key1, $key2, $versionBase, $versionMinor, $versionDigits = Get-KeyComponents -Version $version
    $fullVersion = "$versionBase.$versionMinor.$versionDigits"  # e.g., 15.0.20 or 15.0.19

    # Find the matching product ID
    $productKey = "$key1`-$versionBase`-$versionMinor$(if ($key2 -eq 'jpn') { 'j' })"
    $productEntry = $productMapping | Where-Object { $_[0] -eq $productKey }
    if (-not $productEntry) {
        throw "No product ID found for version $version and language $key2"
    }
    $productId = $productEntry[1]
    Write-Host "Fetching template URL for product: $productId (Version: $fullVersion, TemplateType: $templateType)"

    # Get product details
    $entityResponse = Get-MCATEntity -Catalog 'AWSMarketplace' -EntityId $productId
    if (-not $entityResponse) {
        throw "Failed to retrieve entity for product $productId"
    }
    $entityResponse | Out-String | Write-Host  # Log the full response for debugging

    $productDetails = $entityResponse.Details | ConvertFrom-Json
    if (-not $productDetails) {
        throw "Failed to parse details for product $productId"
    }

    # Find the version matching fullVersion (e.g., 15.0.20)
    $targetVersion = $productDetails.Versions | Where-Object { $_.VersionTitle -eq $fullVersion }
    if (-not $targetVersion) {
        throw "No version $fullVersion found for product $productId"
    }
    $targetVersion | Out-Default | Write-Host

    # Find CloudFormation template in Sources
    $templateName = if ($templateType -eq 'master') { 'lansa-master-win.cfn.template' } else { 'lansa-stack-type-win.cfn.template' }
    $source = $targetVersion.Sources | Where-Object { $_.Template -like "*$templateName" }
    if (-not $source) {
        throw "No matching template ($templateName) found for product $productId, version $fullVersion"
    }

    $url = $source.Template
    Write-Host "Template URL for $version $templateType = $url"

    # Construct variables
    $TemplateUrl = $url

    # Set Azure DevOps variables
    Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]True"
    Write-Host "##vso[task.setvariable variable=TemplateUrl]$TemplateUrl"
    Write-Host "##vso[task.setvariable variable=UserScriptHook]https://s3-ap-southeast-2.amazonaws.com/lansa/scripts/user-script.ps1"
} catch {
    Write-Error "Error retrieving template URL: $_"
    Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]False"
    throw
}