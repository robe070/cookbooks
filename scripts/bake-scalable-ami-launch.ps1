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

Bake-ScalableMsi -VersionText '13SP2 EPC132900' `
            -VersionMajor 13 `
            -VersionMinor 2 `
            -AmazonAMIName "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_RTM_Express*" `
            -GitBranch "patch/ps-scalable-pipeline"