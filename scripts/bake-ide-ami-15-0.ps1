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
. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-IdeMsi -VersionText 'w19d-15-0-DBTST' `
            -VersionMajor 15 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v15\CloudOnly\LanCdCut_L4W15000_4403_210616_EPC150040" `
            -S3DVDImageDirectory "s3://lansa/releasedbuilds/v15/LanDVDcut_L4W15000_latest" `
            -S3VisualLANSAUpdateDirectory "s3://lansa/releasedbuilds/v15/VisualLANSA_L4W15000_latest" `
            -S3IntegratorUpdateDirectory "s3://lansa/releasedbuilds/v15/Integrator_L4W15000_latest" `
            -AmazonAMIName "Windows_Server-2019-English-Full-SQL_2019_Express*" `
            -GitBranch "debug/paas" `
            -UploadInstallationImageChanges $false `
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $true `
            -InstallScalableLicense $true `
            -InstallScalable $false `
            -Win2012 $false `
            -Upgrade $false `
            -KeyPairName 'RobG_id_rsa' `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\id_rsa" `
            -GitUserName 'robe070'
