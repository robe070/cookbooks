# SetMarketplaceVariables.ps1
# This script sets Azure DevOps variables based on input parameters version and templateType
# It uses a lookup table with full URLs, dynamically parsing them into components

param (
    [Parameter(Mandatory=$true)]
    [string]$version,

    [Parameter(Mandatory=$true)]
    [ValidateSet('master', 'shoesize')]
    [string]$templateType
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
    $versionPrefix = "$versionBase.$versionMinor"  # e.g., 15.0

    return $key1, $key2, $versionPrefix, $versionDigits
}

# Function to parse URL into components
function Parse-TemplateUrl {
    param (
        [string]$Url
    )

    # Parse URL using regex to extract components
    if ($Url -match '^https:\/\/([^.]+)\.s3\.([^.]+)\.amazonaws\.com\/([^\/]+)\/([^\/]+)\/(.+)$') {
        return @{
            BucketName = $Matches[1]  # e.g., awsmp-cft-992382380361-1708727387563
            BucketRegion = $Matches[2]  # e.g., us-east-1
            TemplateKeyPrefix = "$($Matches[3])/"  # e.g., a305b7d6-efa2-4265-be5b-49ef9d3069b5/
            ProductId = $Matches[4]  # e.g., prod-7c4xdvxkskdfs
        }
    } else {
        throw "Invalid URL format: $Url"
    }
}

# Define the lookup table with full URLs
$templateData = @{
    # Version 19
    'master_w19d_eng_19' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/60d93b08-227c-428e-ab17-7b75046a5daf/prod-7c4xdvxkskdfs/05c20fff-a79a-47f1-b157-6b6130d2f32e/lansa-master-win.cfn.template'
    'shoesize_w19d_eng_19' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/a305b7d6-efa2-4265-be5b-49ef9d3069b5/prod-7c4xdvxkskdfs/ae285e2e-5bde-4b5f-85af-87d08a180697/lansa-stack-type-win.cfn.template'
    'master_w19d_jpn_19' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/ae7d2d02-ba00-49b2-931e-97c27943438c/prod-csfkcd5qvncle/5b59d4f6-9037-433d-ba37-8ef7bddae066/lansa-master-win.cfn.template'
    'shoesize_w19d_jpn_19' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/6a47c447-03cb-4188-9d79-f05b84ef6e9f/prod-csfkcd5qvncle/bb190ac7-8353-4ad8-bb99-8762ab3e4aee/lansa-stack-type-win.cfn.template'
    # Version 20
    'master_w19d_eng_20' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/07bb8e79-19cf-4313-ad19-f2c8b7efa5d8/prod-7c4xdvxkskdfs/94ed0770-ed4e-45e0-8402-f256180b23ac/lansa-master-win.cfn.template'
    'shoesize_w19d_eng_20' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/af510002-9567-483a-8c7b-85ce7efb8012/prod-7c4xdvxkskdfs/06d0c41f-372a-486c-a1b2-a2259a5f878e/lansa-stack-type-win.cfn.template'
    'master_w19d_jpn_20' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/599d4836-0fa2-4393-a027-a42ed42a9a74/prod-csfkcd5qvncle/f162c4aa-278d-4e30-9619-570f4ed72fd5/lansa-master-win.cfn.template'
    'shoesize_w19d_jpn_20' = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/f2708c67-8785-411d-86d5-73e7dcb15aac/prod-csfkcd5qvncle/04a665af-9919-4290-bc01-b9acca6f3275/lansa-stack-type-win.cfn.template'

    # Additional key combinations can be added here as needed
    # e.g., 'master_w25d_eng_19', 'shoesize_w25d_jpn_19', etc.
}

# Get key components
$key1, $key2, $versionPrefix, $versionDigits = Get-KeyComponents -Version $version
$key = "${templateType}_${key1}_${key2}_${versionDigits}"

Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]False"

# Retrieve data from the lookup table
if ($templateData.ContainsKey($key)) {
    $url = $templateData[$key]
    $data = Parse-TemplateUrl -Url $url

    # Construct variables
    $TemplateUrl = $url
    $MPS3BucketName = $data.BucketName
    $MPS3BucketRegion = $data.BucketRegion
    $MPS3KeyPrefix = $data.TemplateKeyPrefix
    $ImageId = "/aws/service/marketplace/$($data.ProductId)/$versionPrefix.$versionDigits"

    # Set Azure DevOps variables
    Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]True"
    Write-Host "##vso[task.setvariable variable=TemplateUrl]$TemplateUrl"
    Write-Host "##vso[task.setvariable variable=MPS3BucketName]$MPS3BucketName"
    Write-Host "##vso[task.setvariable variable=MPS3BucketRegion]$MPS3BucketRegion"
    Write-Host "##vso[task.setvariable variable=MPS3KeyPrefix]$MPS3KeyPrefix"
    Write-Host "##vso[task.setvariable variable=ImageId]$ImageId"

    Write-Host "##vso[task.setvariable variable=UserScriptHook]https://s3-ap-southeast-2.amazonaws.com/lansa/scripts/user-script.ps1"
} else {
    Write-Error "No data found for key: $key"
    throw
}