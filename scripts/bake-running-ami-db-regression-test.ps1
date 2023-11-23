<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"
. "$Script:IncludeDir\bake-running-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-RunningAMI -VersionText 'w19d-15-0-DBTST' `
            -LansaVersion '150060' `
            -VersionMajor 15 `
            -VersionMinor 0 `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\AzureDevOps.pem" `
            -Title 'Database Regression Test'


# -KeyPairPath "$ENV:USERPROFILE\\.ssh\\id_rsa.pem" `
