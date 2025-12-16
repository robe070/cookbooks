<#
.SYNOPSIS

Bake a LANSA image for Azure

.DESCRIPTION

.EXAMPLE


#>

# $DebugPreference = "Continue"
$VerbosePreference = "SilentlyContinue"

$MyInvocation.MyCommand.Path
$Script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-IdeMsi -VersionText 'w25-sql-rjg' `
            -VersionMajor 16 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v16\SPIN0332_LanDVDcut_L4W16000_4403_210616_EPC160040" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v16/LanDVDcut_L4W16000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v16/VisualLANSA_L4W16000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v16/Integrator_L4W16000_latest" `
            -AmazonAMIName "Windows_Server-2025-English-Full-SQL_2025_Express*" `
            -GitBranch "debug/paas" `
            -Cloud "AWS" `
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $false `
            -InstallScalable $true `
            -Win2012 $false `
            -RunWindowsUpdates $false `
            -ManualWinUpd $false `
            -SkipSlowStuff $false `
            -OnlySaveImage $false `
            -CreateVM $true `
            -KeyPairName 'RobG_id_rsa' `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\id_rsa" `
            -GitUserName 'robe070'
