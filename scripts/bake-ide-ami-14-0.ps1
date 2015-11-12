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

Bake-IdeMsi -VersionText '14.0GA' `
            -VersionMajor 14 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\LANSABUILDPC14\l4wbuild\trunk\LanCdCut_tip_4120_151112_GA" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName "Windows_Server-2012-R2_RTM-English-64Bit-SQL_2014_SP1_Express*" `
            -GitBranch "feature/finalise-14"