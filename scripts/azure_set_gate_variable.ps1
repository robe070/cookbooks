param (
    [Parameter(Mandatory=$true)]
    [string]
    $Version,

    [Parameter(Mandatory=$true)]
    [string]
    $osName
   )

Write-Host "version is - $Version"
# Set the Gate variable if the file exists
$path = "$($env:System_DefaultWorkingDirectory)/_Lansa Images - Cookbooks/$Version/$Version.txt"
if (Test-Path $path) {
    $rawUri = Get-Content -Path $path -Raw
    Write-Host "ImageUrl is $rawUri"
    $rawUri -match '[\w-]+\.vhd'
    Write-Host "ImageName value is $Matches[0]"
    $Matches[0] -match '[^.]+'
    $sku = $Matches[0]
    Write-Host "SKU is $sku"
    Write-Host "##vso[task.setvariable variable=Sku;isOutput=true]$sku"
    $uri = "/subscriptions/$env:SUBSCRIPTIONID/resourceGroups/$env:RESOURCEGROUPNAME/providers/Microsoft.Compute/images/$($Matches[0])image"
    # Set Variables
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$uri"
    Write-Host "##vso[task.setvariable variable=IsEnabled;isOutput=true]True"
    Write-Host "##vso[task.setvariable variable=osName;isOutput=true]$osName"
    Write-Host "##vso[task.setvariable variable=Version;isOutput=true]$Version"
    Write-host "The value of Variable IsEnabled is updated to True and output variable ImageUrl to $uri"
} else {
    Write-Host "Artifact path does NOT exist for $Version"
}
