﻿<#
.SYNOPSIS

Bake a Japanese LANSA image for AWS from the LANSA ENG image.

Note: MUST run Windows Updates as the language packs are from the original release image

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

# Note that the first 3 characters of VersionText are important. w12, w16 or w19 to match the Windows version
# When InstallScalable = $true, VersionMajor & VersionMinor Must be 14.2 or 15.0. These values are important in locating the "start here" html page

Bake-IdeMsi -VersionText 'w19d-15-0-tst' `
            -VersionMajor 15 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "ignore" `
            -S3DVDImageDirectory "ignore" `
            -S3VisualLANSAUpdateDirectory "ignore" `
            -S3IntegratorUpdateDirectory "ignore" `
            -AmazonAMIName "LANSA Scalable License  w19d-15-0-4 *" `
            -Language 'JPN' `
            -GitBranch "debug/paas" `
            -Cloud "AWS" `
            -InstallBaseSoftware $false `
            -InstallSQLServer $false `
            -InstallIDE $false `
            -InstallScalable $false `
            -InstallLanguagePack `
            -Win2012 $false `
            -RunWindowsUpdates $false `
            -ManualWinUpd $false `
            -SkipSlowStuff $false `
            -OnlySaveImage $false `
            -CreateVM $true `
            -KeyPairName 'RobG_id_rsa' `
            -KeyPairPath "$ENV:USERPROFILE\\.ssh\\id_rsa" `
            -GitUserName 'robe070'