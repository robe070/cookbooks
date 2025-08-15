# SetMarketplaceVariables.ps1
# This script sets Azure DevOps variables based on input parameters baseImageName and templateType
# It uses a predefined table to map keys to AWS Marketplace template data

param (
    [Parameter(Mandatory=$true)]
    [ValidateSet('w19d-15-0', 'w19d-16-0', 'w25d-15-0', 'w25d-16-0', 'w19d-15-0j', 'w19d-16-0j', 'w25d-15-0j', 'w25d-16-0j')]
    [string]$baseImageName,

    [Parameter(Mandatory=$true)]
    [ValidateSet('master', 'stacktype')]
    [string]$templateType
)

# Function to derive key components from baseImageName
function Get-KeyComponents {
    param (
        [string]$BaseImageName
    )

    $key1 = $BaseImageName.Split('-')[0]  # e.g., w19d
    $key2 = if ($BaseImageName -like '*j') { 'jpn' } else { 'eng' }

    return $key1, $key2
}

# Define the lookup table
$templateData = @{
    'w19d_eng_stacktype' = @{
        TemplateUrl = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/f632327c-e7fc-45fc-a594-d70141e84988/prod-7c4xdvxkskdfs/a50e24ef-1e9d-43fd-aa11-e7a2149ef9d7/lansa-stack-type-win.cfn.template'
        MPS3BucketName = 'awsmp-cft-992382380361-1708727387563'
        MPS3BucketRegion = 'us-east-1'
        MPS3KeyPrefix = 'f632327c-e7fc-45fc-a594-d70141e84988/'
    }
    'w19d_eng_master' = @{
        TemplateUrl = 'https://awsmp-cft-992382380361-1708727387563.s3.us-east-1.amazonaws.com/4d884544-55ce-48c3-b9e0-0e624968ff19/prod-7c4xdvxkskdfs/ed7dce1e-63fb-4e8b-99b2-a9c77236cb88/lansa-master-win.cfn.template'
        MPS3BucketName = 'awsmp-cft-992382380361-1708727387563'
        MPS3BucketRegion = 'us-east-1'
        MPS3KeyPrefix = '4d884544-55ce-48c3-b9e0-0e624968ff19/'
    }
    # Additional key combinations can be added here as needed
    # e.g., 'w19d_jpn_stacktype', 'w19d_jpn_master', 'w22d_eng_stacktype', etc.
}

# Get key components
$key1, $key2 = Get-KeyComponents -BaseImageName $baseImageName
$key = "${key1}_${key2}_${templateType}"

Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]False"

# Retrieve data from the lookup table
if ($templateData.ContainsKey($key)) {
    $data = $templateData[$key]

    # Set Azure DevOps variables
    Write-Host "##vso[task.setvariable variable=UseMarketplaceVariables]True"
    Write-Host "##vso[task.setvariable variable=TemplateUrl]$($data.TemplateUrl)"
    Write-Host "##vso[task.setvariable variable=MPS3BucketName]$($data.MPS3BucketName)"
    Write-Host "##vso[task.setvariable variable=MPS3BucketRegion]$($data.MPS3BucketRegion)"
    Write-Host "##vso[task.setvariable variable=MPS3KeyPrefix]$($data.MPS3KeyPrefix)"
} else {
    Write-Error "No data found for key: $key"
    exit 1
}