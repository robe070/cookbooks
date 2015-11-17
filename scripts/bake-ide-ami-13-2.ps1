<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"

. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-IdeMsi -VersionText '13SP2' `
            -VersionMajor 13 `
            -VersionMinor 2 `
            -LocalDVDImageDirectory "Z:\v13\SPIN0330_LanDVDcut_L4W13200_4088_EPC132900" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v13/LanDVDcut_L4W13200_4088_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v13/VisualLANSA_L4W13200_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v13/Integrator_L4W13200_latest" `
            -AmazonAMIName "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_SP1_Express*"`
            -GitBranch "support/L4W13200_IDE"