# Include directory is where this script is executing
$IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$IncludeDir\dot-createlicense.ps1"

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

CreateLicence "c:\\lansa\\PackerScripts\\LansaScalableLicense.pfx" $args[0] "LANSA Scalable License" "ScalableLicensePrivateKey"
