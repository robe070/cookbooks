<#
.SYNOPSIS

Test licenses are installed and working.

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE

#>
Param(
    [Parameter(Mandatory=$true)]
    [String] $ImgName,

    [Parameter(Mandatory=$false)]
    [switch] $EnforceMarketplaceProductCodeValidation
)
. "c:\lansa\scripts\dot-CommonTools.ps1"

$EnforceMarketplaceProductCodeValidation = $True

if ( -not $script:IncludeDir)
{
	$script:IncludeDir = 'c:\lansa\scripts'
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

if ( $EnforceMarketplaceProductCodeValidation) {
    # This script sets the Production value under HKEY_LOCAL_MACHINE\Software\LANSA to True (REG_DWORD, value 1).
    # Assumptions:
    # - Runs in Azure DevOps self-hosted Windows agent context.
    # - Compatible with PowerShell 5.1.
    # - Requires administrative privileges to write to HKLM.

    try {
        $registryPath = "HKLM:\Software\LANSA"
        $valueName = "Production"
        $valueData = 1  # Boolean True as REG_DWORD

        # Check if the registry key exists, create it if it doesn't
        if (-not (Test-Path -Path $registryPath)) {
            throw "Registry key $registryPath not found."
        } else {
            Write-Host "Registry key $registryPath found."
        }

        # Set the Production value to True (1)
        Set-ItemProperty -Path $registryPath -Name $valueName -Value $valueData -Type DWord -Force
        Write-Host "Production value set to True (1)."

        # Verify the value was set
        $setValue = Get-ItemProperty -Path $registryPath -Name $valueName -ErrorAction Stop
        if ($setValue.$valueName -eq $valueData) {
            Write-Host "Production value verified as True (1)."
        } else {
            Write-Error "Failed to verify Production value. Expected: $valueData, Found: $($setValue.$valueName)"
        }
    } catch {
        Write-Error "Error setting registry value: $_"
        exit 1
    }
}

# Verifies the VersionText Registry with the Image SKU
$VersionTextValue = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'VersionText').VersionText
Write-Host "$(Log-Date) Verifying the Registry entry for VersionText $VersionTextValue and the SKU $ImgName"
if ($VersionTextValue -ne $ImgName) {
    Write-Host "$(Log-Date) Registry entry for VersionText $VersionTextValue doesn't match the SKU $ImgName"
    cmd /c exit 1    #Set $LASTEXITCODE
    throw "$(Log-Date) Registry entry for VersionText $VersionTextValue is invalid"
}
Write-GreenOutput "Image SKU tested successfully" | Out-Default | Write-Host

Write-Host ("PSScriptRoot = $PSScriptRoot")
& "$script:IncludeDir\..\tests\CheckAWSSSmAgent.ps1"
