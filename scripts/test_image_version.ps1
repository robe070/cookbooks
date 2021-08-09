Install-Module -Name Az.Compute -AllowClobber -Force
Write-Host "$(Gate.Sku)"
$SkuName = "$(Gate.Sku)"

$var=ConvertFrom-Json '$(deploymentOutput)'

# Download TestImageVersion PS Script
New-Item -Path "$(CookbooksSource)\Tests\Tests" -ItemType Directory -verbose
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/robe070/cookbooks/$(CookbooksBranch)/Tests/TestImageVersion.ps1" -OutFile "$(CookbooksSource)\Tests\TestImageVersion.ps1" -verbose

$vmssName = $var.scalesetName.value
Write-Host $vmssName | Out-Default

 # Execute the TestImageVersion PS Script
Write-Host "Test the image version $SkuName by executing the script in the VMSS $vmssName" | Out-Default | Write-Verbose
$result = Invoke-AzVmssVMRunCommand -ResourceGroupName "BakingDP-Preview-AE-w16d-14-2" -VMScaleSetName $vmssName -InstanceId '0' -CommandId 'RunPowerShellScript' -ScriptPath "$(CookbooksSource)\Tests\TestImageVersion.ps1" -Parameter @{ImgName = $SkuName}
$result | Out-Default | Write-Host
if ($result.Value[1].message -eq "") {
    Write-Host "Tested the image version in the VMSS successfully."
} else {
    throw $result.Value[1].message

