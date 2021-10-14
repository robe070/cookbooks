param (
    [Parameter(Mandatory=$true)]
    [string]
    $SkuName,

    [Parameter(Mandatory=$true)]
    [string]
    $deploymentOutput
)
# Example:
# $ENV:COOKBOOKSOURCE = 'c:'
# $ENV:COOKBOOKSBRANCH = 'debug/paas'
# $ENV:RESOURCEGROUP = 'BakingDP-Preview-UE-w12r2d-15-0'
# $SkuName = 'w12r2d-15-0-13'
# $deploymentOutput = '{"dbServerName":{"type":"String","value":"njrtbyk32sqlserver.database.windows.net"},"dbName":{"type":"String","value":"lansa"},"lbFqdn":{"type":"String","value":"https://agnjrtbyk.eastus.cloudapp.azure.com"},"rdpAddress":{"type":"String","value":"njrtbyk.eastus.cloudapp.azure.com:50000"},"offerId":{"type":"String","value":"lansa-scalable-license-preview"},"scalesetName":{"type":"String","value":"dbnjrtbyk"},"skuId":{"type":"String","value":"w12r2d-15-0"}}'
# Note, for $deploymentOutput, only scalesetName.value is used in this script. So just replace 'dbnjrtbyk' with your value

Write-Host $SkuName

$var=ConvertFrom-Json $deploymentOutput

# Download TestImageVersion PS Script
New-Item -Path "$($env:COOKBOOKSSOURCE)\Tests\Tests" -ItemType Directory -verbose -ErrorAction SilentlyContinue
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/robe070/cookbooks/$($env:COOKBOOKSBRANCH)/Tests/TestImageVersion.ps1" -OutFile "$($env:COOKBOOKSSOURCE)\Tests\TestImageVersion.ps1" -verbose

$vmssName = $var.scalesetName.value
Write-Host $vmssName

# Write-Host "Wait 15 minutes for the Azure Agent to potentially be updated"
# Start-Sleep 900

 # Execute the TestImageVersion PS Script
Write-Host "Test the image version $SkuName by executing the script in the VMSS $vmssName"
$result = Invoke-AzVmssVMRunCommand -ResourceGroupName "$env:RESOURCEGROUP" -VMScaleSetName $vmssName -InstanceId '0' -CommandId 'RunPowerShellScript' -ScriptPath "$($env:COOKBOOKSSOURCE)\Tests\TestImageVersion.ps1" -Parameter @{ImgName = $SkuName}
$result | Out-Default | Write-Host
if($result.Value[1].message -eq "") {
    Write-Host "Tested the image version in the VMSS successfully."
} else {
    throw $result.Value[1].message
}
