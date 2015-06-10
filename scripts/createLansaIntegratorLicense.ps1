# Include directory is where this script is executing
$IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$IncludeDir\dot-createlicense.ps1"

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

CreateLicence "c:\\packerTemp\\LANSAIntegratorLicense.pfx" $args[0] "LANSA Integrator License" "IntegratorLicensePrivateKey"
