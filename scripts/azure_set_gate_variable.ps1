param (
    [Parameter(Mandatory=$true)]
    [string]
    $Version
   )


# Set the Gate variable if the file exists
$path = "$($env:System_DefaultWorkingDirectory)/_Lansa Images - Cookbooks/$Version/$Version.txt"
if (Test-Path $path) {
    $rawUri = Get-Content -Path $path -Raw
    Write-Host $rawUri | Out-Default | Write-Verbose
    $rawUri -match '[\w-]+\.vhd'
    Write-Host $Matches[0] | Out-Default | Write-Verbose
    $Matches[0] -match '[^.]+'
    $sku = $Matches[0]
    Write-Host $sku | Out-Default | Write-Verbose
    Write-Host "##vso[task.setvariable variable=Sku;isOutput=true]$sku" | Out-Default | Write-Verbose
    $uri = "/subscriptions/$env:SUBSCRIPTIONID/resourceGroups/$env:RESOURCEGROUPNAME/providers/Microsoft.Compute/images/$($Matches[0])image"
    # Set Variables
    Write-Host "##vso[task.setvariable variable=ImageUrl;isOutput=true]$uri" | Out-Default | Write-Verbose
    Write-Host "##vso[task.setvariable variable=IsEnabled;isOutput=true]True" | Out-Default | Write-Verbose
    Write-host "The value of Variable IsEnabled is updated to True and output variable ImageUrl to $uri" | Out-Default | Write-Verbose
}
