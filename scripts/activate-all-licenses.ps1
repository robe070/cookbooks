<#
.SYNOPSIS

Activate the licenses on a LANSA Scalable image.

.EXAMPLE

c:\\lansa\\scripts\\activate-scalable-license.ps1 -webuser 'pcxuser'

#>
param(
    [String]$webuser = 'PCXUSER2'
)

# Log-Date can't be used yet as Framework has not been loaded

Write-Output "Initialising environment - presumed not running through RemotePS"
$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

Write-Debug ("webuser = $webuser")

try
{
	Write-output ("Remap licenses to new instance Guid and set permissions so that $webuser may access them" )

    $LicenseCount = 0

    [string[][]]$Keys = @(@("LANSA Scalable License", "ScalableLicensePrivateKey"), @("LANSA Integrator License", "IntegratorLicensePrivateKey"), @("LANSA Development License", "DevelopmentLicensePrivateKey") )
    foreach ( $LicensePrivateKey in $Keys ) {
        $LicensePrivateKey[0]
        $LicensePrivateKey[1]
        $LicensePrivateKeyValue = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $LicensePrivateKey[1] -ErrorAction SilentlyContinue
        if ( $LicensePrivateKeyValue ) {
            Map-LicenseToUser $LicensePrivateKey[0] $LicensePrivateKey[1] $webuser
            $LicenseCount++
        } else {
            Write-Warning "$(LOG-DATE) $($LicensePrivateKey[1]) not installed"
        }
    }

    if ( $LicenseCount -eq 0 ) {
        # This code will throw an error at some stage unless a Cloud Account Id license file exists
        Write-Host( "No scalable licenses found. Look for Cloud Account Id licenses..." )
        $LicenseDir = (Get-ItemProperty -Path HKLM:\Software\lansa\Common -Name 'LicenseDir' -ErrorAction Continue).LicenseDir
        if ( -not $LicenseDir ) {
            throw "The LicenseDir registry entry does not exist"
        }

        if ( Test-Path $LicenseDir ) {
            if ( Test-Path "$LicenseDir\x_lic*.5.lic" ) {
                Write-Host "List the Cloud Account Id licenses..."
                Get-ChildItem "$LicenseDir\x_lic*.5.lic"
            } else {
                throw "There are no cloud account id licenses"
            }
        } else {
            throw "The Cloud Account Id license directory $LicenseDir does not exist"
        }
        Write-Host( "Cloud Account Id license(s) exist")
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
