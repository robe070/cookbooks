<#
.SYNOPSIS

Test licenses are installed and working.

IMPORTANT:" To be run in a new instance created from the baked image, NOT while creating the image itself.

.EXAMPLE

#>

if ( -not $script:IncludeDir)
{
    $script:IncludeDir = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Path) '..\scripts'

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
    cd "$Script:IncludeDir\..\tests"

    $VerbosePreference = 'SilentlyContinue'

    Write-Verbose "Test verbose"

    $WebUser = 'PCXUSER2'
    Write-GreenOutput "Note: MUST create the user $webuser manually before running this script AND add to local Administrators group"

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

	# Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" $webuser
	# Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser
} catch {
    Write-RedOutput $_
    throw "$(Log-Date) License installation error"
}
Write-GreenOutput "All licenses tested successfully"