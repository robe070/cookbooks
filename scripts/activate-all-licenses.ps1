<#
.SYNOPSIS

Activate the licenses on a LANSA Scalable image.

.EXAMPLE

c:\\lansa\\scripts\\activate-scalable-license.ps1 -webuser 'pcxuser'

#>
param(
    [String]$webuser = 'PCXUSER2'
)

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

Write-Debug ("webuser = $webuser")

try
{
	Write-output ("Remap licenses to new instance Guid and set permissions so that webuser may access them" )

    [string[][]]$Keys = @(@("LANSA Scalable License", "ScalableLicensePrivateKey"), @("LANSA Integrator License", "IntegratorLicensePrivateKey"), @("LANSA Development License", "DevelopmentLicensePrivateKey") )
    foreach ( $LicensePrivateKey in $Keys ) {
        $LicensePrivateKey[0]
        $LicensePrivateKey[1]
        $LicensePrivateKeyValue = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $LicensePrivateKey[1] -ErrorAction SilentlyContinue
        if ( $LicensePrivateKeyValue ) {
            Map-LicenseToUser $LicensePrivateKey[0] $LicensePrivateKey[1] $webuser
        } else {
            Write-Warning "$(LOG-DATE) $($LicensePrivateKey[1]) not installed"
        }
    }

    Write-Output ("License activation completed successfully")
}
catch
{
    cmd /c exit 1
    throw "License activation error"
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
