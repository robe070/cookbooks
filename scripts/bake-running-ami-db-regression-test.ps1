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

Bake-RunningAMI -VersionText 'w25-DB-REGRESSION-TEST' `
            -LansaVersion '160000' `
            -VersionMajor 16 `
            -VersionMinor 0 `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\AzureDevOps.pem" `
            -Title 'Database Regression Test' `
            -NoSysprep


# -KeyPairPath "$ENV:USERPROFILE\\.ssh\\id_rsa.pem" `
