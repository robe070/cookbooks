<#
.SYNOPSIS

Test licenses are installed and working.

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE

#>
Param(
    [Parameter(Mandatory=$true)] [String] $ImgName
)
. "c:\lansa\scripts\dot-CommonTools.ps1"

if ( -not $script:IncludeDir)
{
	$script:IncludeDir = 'c:\lansa\scripts'
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS" | Out-Default | Write-Host
}

# Verifies the VersionText Registry with the Image SKU
$VersionTextValue = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'VersionText').VersionText
Write-YellowOutput "Verifying the Registry entry for VersionText $VersionTextValue and the SKU $ImgName" | Out-Default | Write-Host
if ($VersionTextValue -ne $ImgName) {
    Write-RedOutput "Registry entry for VersionText $VersionTextValue doesn't match the SKU $ImgName" | Out-Default | Write-Host
    throw "$(Log-Date) Registry entry for VersionText $VersionTextValue is invalid"
}
Write-GreenOutput "Image SKU tested successfully" | Out-Default | Write-Host

& "$PSScriptRoot\CheckAWSSSmAgent.ps1"