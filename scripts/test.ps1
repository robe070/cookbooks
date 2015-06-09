# Include directory is where this script is executing
$script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$script:IncludeDir\dot-map-licensetouser.ps1"

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" "PCXUSER2"