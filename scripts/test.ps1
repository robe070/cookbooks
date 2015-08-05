# Include directory is where this script is executing
$script:IncludeDir = Split-Path -Parent $Script:MyInvocation.MyCommand.Path

# Includes
. "$script:IncludeDir\dot-wait-EC2State.ps1"

Wait-EC2State i-1e4ce220 'shutting down'
