﻿<#
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

Bake-IdeMsi -VersionText 'IDESQL-E1' `
            -VersionMajor 14 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\CloudOnly\LanCdCut_tip_4120_EPC140020" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName "SQL2014-A-Eimage" `
            -GitBranch "feature/azure-ide" `
            -Cloud "Azure" `
            -InstallBaseSoftware $false `
            -InstallSQLServer $false `
            -InstallIDE $true