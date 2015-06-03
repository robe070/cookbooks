# Include directory is where this script is executing
$script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$script:IncludeDir\dot-restart-ifneeded.ps1"

Restart-IfNeeded
