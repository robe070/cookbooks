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

Bake-IdeMsi -VersionText '14beta' `
            -VersionMajor 14 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\lansabuildpc14\l4wbuild\Trunk\LanCdCut_tip_4117_150914_reg" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AMIName "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_RTM_Express*" `
            -GitBranch "feature/finalise-14"