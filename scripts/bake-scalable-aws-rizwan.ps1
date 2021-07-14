<#
.SYNOPSIS

Bake a LANSA image for Azure

.DESCRIPTION

.EXAMPLE


#>

# $DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$Script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

Bake-IdeMsi -VersionText 'w19-base-ra' `
            -VersionMajor 15 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\SPIN0332_LanDVDcut_L4W14100_4138_160727_GA" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName "Windows_Server-2019-English-Full-Base*" `
            -GitBranch "feature/62" `
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
            -KeyPairName 'riz_test1' `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\riz_test1.pem" `
            -GitUserName 'CelestialSystem' `
            -ExternalIPAddresses 192.168.10.10/32, 10.10.1.1/32, 224.23.2.2/32, 106.211.132.182/32
