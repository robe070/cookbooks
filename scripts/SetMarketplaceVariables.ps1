# SetMarketplaceVariables.ps1
# This script sets Azure DevOps variables based on input parameters baseImageName, templateType, and VersionDigits
# It uses a predefined table to map keys to AWS Marketplace template data, with deduplicated elements

param (
    [Parameter(Mandatory=$true)]
    [string]$version,

    [Parameter(Mandatory=$true)]
    [ValidateSet('master', 'ShoeSize')]
    [string]$templateType
)

# Function to derive key components from baseImageName
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
    $versionPrefix = "$versionBase.$versionMinor"  # e.g., 15.0

    return $key1, $key2, $versionPrefix, $versionDigits
}
# Define the lookup table with deduplicated elements and combined w19d_eng entry
$templateData = @{
    'w19d_eng' = @{
        ProductId = 'prod-7c4xdvxkskdfs'
        StackTypeTemplateFile = 'a50e24ef-1e9d-43fd-aa11-e7a2149ef9d7/lansa-stack-type-win.cfn.template'
        StackTypeTemplateKeyPrefix = 'f632327c-e7fc-45fc-a594-d70141e84988/'
        MasterTemplateFile = 'ed7dce1e-63fb-4e8b-99b2-a9c77236cb88/lansa-master-win.cfn.template'
        MasterTemplateKeyPrefix = 'f632327c-e7fc-45fc-a594-d70141e84988/'
    }
    'w19d_jpn' = @{
        ProductId = 'prod-csfkcd5qvncle'
        StackTypeTemplateFile = 'bb190ac7-8353-4ad8-bb99-8762ab3e4aee/lansa-stack-type-win.cfn.template'
        StackTypeTemplateKeyPrefix = '6a47c447-03cb-4188-9d79-f05b84ef6e9f/'
        MasterTemplateFile = '5b59d4f6-9037-433d-ba37-8ef7bddae066/lansa-master-win.cfn.template'
        MasterTemplateKeyPrefix = 'ae7d2d02-ba00-49b2-931e-97c27943438c/'
    }
    # Additional key combinations can be added here as needed
    # e.g., 'w22d_eng', 'w25d_jpn', etc.
}

# Get key components
$key1, $key2, $versionPrefix, $versionDigits = Get-KeyComponents -Version $version
$key = "${key1}_${key2}"

Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]False"

# Retrieve data from the lookup table
if ($templateData.ContainsKey($key)) {
    $data = $templateData[$key]

    $MPS3BucketName = 'awsmp-cft-992382380361-1708727387563'
    $MPS3BucketRegion = 'us-east-1'

    # Select the appropriate template file based on templateType
    $TemplateFile = if ($templateType -eq 'ShoeSize') { $data.StackTypeTemplateFile } else { $data.MasterTemplateFile }
    $TemplateKeyPrefix = if ($templateType -eq 'ShoeSize') { $data.StackTypeTemplateKeyPrefix } else { $data.MasterTemplateKeyPrefix }

    # Construct variables
    $TemplateUrl = "https://$($MPS3BucketName).s3.$($MPS3BucketRegion).amazonaws.com/$($TemplateKeyPrefix)$TemplateFile"
    $MPS3KeyPrefix = $TemplateKeyPrefix
    $ImageId = "/aws/service/marketplace/$($data.ProductId)/$versionPrefix.$VersionDigits"

    # Set Azure DevOps variables
    Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]True"
    Write-Host "##vso[task.setvariable variable=TemplateUrl]$TemplateUrl"
    Write-Host "##vso[task.setvariable variable=MPS3BucketName]$MPS3BucketName"
    Write-Host "##vso[task.setvariable variable=MPS3BucketRegion]$MPS3BucketRegion"
    Write-Host "##vso[task.setvariable variable=MPS3KeyPrefix]$MPS3KeyPrefix"
    Write-Host "##vso[task.setvariable variable=ImageId]$ImageId"
} else {
    Write-Error "No data found for key: $key"
    exit 1
}