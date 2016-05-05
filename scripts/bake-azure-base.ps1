<#
.SYNOPSIS

Bake a LANSA image for Azure

.DESCRIPTION

.EXAMPLE


#>

# $DebugPreference = "Continue"
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

# Image value should be this but there is a defect in the latest Azure image:
#            -AmazonAMIName "Windows Server 2012 R2 Datacenter" `

Bake-IdeMsi -VersionText 'WS2012R2-A' `
            -VersionMajor 14 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\CloudOnly\LanCdCut_tip_4120_EPC140020" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName "a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-20160229-en.us-127GB.vhd" `
            -GitBranch "feature/azure-ide" `
            -Cloud "Azure" `
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $false
