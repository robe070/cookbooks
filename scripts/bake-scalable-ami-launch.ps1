<#
.SYNOPSIS

Bake a LANSA Scalable AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"

. "$Script:IncludeDir\bake-scalable-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-ScalableMsi -VersionText '13SP2 EPC132901' `
            -VersionMajor 13 `
            -VersionMinor 2 `
            -AmazonAMIName "WINDOWS_2012R2_SQL_SERVER_EXPRESS_2014" `
            -GitBranch "support/L4W13200_scalable"