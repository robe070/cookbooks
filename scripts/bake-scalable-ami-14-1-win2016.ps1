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

Bake-IdeMsi -VersionText '14.1 EPC141050' `
            -VersionMajor 14 `
            -VersionMinor 1 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\CloudOnly\SPIN0334_LanDVDcut_L4W14100_4138_160727_EPC1410xx" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v14/VisualLANSA_L4W14100_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v14/Integrator_L4W1400_latest" `
            -AmazonAMIName "Windows_Server-2016-English-Full-SQL_2017_Express*" `
            -GitBranch "trunk"`
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $false `
            -InstallScalable $true `
            -Win2012 $false
