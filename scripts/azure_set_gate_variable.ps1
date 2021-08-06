param (
    [Parameter(Mandatory=$true)]
    [string]
    $Version
   )

Write-Host "version is - $Version"
# Set the Gate variable if the file exists
$path = "$($env:System_DefaultWorkingDirectory)/_Lansa Images - Cookbooks/$Version/$Version.txt"
if (Test-Path $path) {
    $rawUri = Get-Content -Path $path -Raw
    Write-Host "Uri is $rawUri"
    $rawUri -match '[\w-]+\.vhd'
    Write-Host "Matches[0] value $Matches[0]"
    $Matches[0] -match '[^.]+'
    $sku = $Matches[0]
    Write-Host "Sku is $sku"
    Write-Host "##vso[task.setvariable variable=Sku;isOutput=true]$sku"
    $uri = "/subscriptions/$env:SUBSCRIPTIONID/resourceGroups/$env:RESOURCEGROUPNAME/providers/Microsoft.Compute/images/$($Matches[0])image"
    # Set Variables
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$uri"
    Write-Host "##vso[task.setvariable variable=IsEnabled;isOutput=true]True"
    Write-host "The value of Variable IsEnabled is updated to True and output variable ImageUrl to $uri"
} else {
    Write-Host "Artifact path does NOT exist for $Version"
}
