param (
    [Parameter(Mandatory=$false)]
    [string]
    $TestVersion,

    [Parameter(Mandatory=$true)]
    [string]
    $Version,

    [Parameter(Mandatory=$false)]
    [string]
    $TestVersionPrev,

    [Parameter(Mandatory=$true)]
    [string]
    $deploymentOutput
)


Install-Module -Name Az.Compute -AllowClobber -Force
if ("$($env:IMAGERELEASESTATE)" -eq "Production") {
    $SkuName = "$($Version)-$($TestVersion)"
} else {
    $SkuName = "$($Version)-$($TestVersionPrev)"
}
Write-Host $SkuName | Out-Default

$var=ConvertFrom-Json $deploymentOutput

# Download TestImageVersion PS Script
New-Item -Path "$($env:COOKBOOKSSOURCE)\Tests\Tests" -ItemType Directory -verbose
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/robe070/cookbooks/$($env:COOKBOOKSBRANCH)/Tests/TestImageVersion.ps1" -OutFile "$($env:COOKBOOKSSOURCE)\Tests\TestImageVersion.ps1" -verbose

$vmssName = $var.scalesetName.value
Write-Host $vmssName | Out-Default

 # Execute the TestImageVersion PS Script
Write-Host "Test the image version $SkuName by executing the script in the VMSS $vmssName" | Out-Default | Write-Verbose
$result = Invoke-AzVmssVMRunCommand -ResourceGroupName "$env:RESOURCEGROUP" -VMScaleSetName $vmssName -InstanceId '0' -CommandId 'RunPowerShellScript' -ScriptPath "$($env:COOKBOOKSSOURCE)\Tests\TestImageVersion.ps1" -Parameter @{ImgName = $SkuName}
$result | Out-Default | Write-Host
if($result.Value[1].message -eq "") {
    Write-Host "Tested the image version in the VMSS successfully."
} else {
    throw $result.Value[1].message
}
