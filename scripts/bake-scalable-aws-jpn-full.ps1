<#
.SYNOPSIS

Bake a Japanese LANSA image for AWS

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

Bake-IdeMsi -VersionText 'w16dxx-14-2-xxj' `
            -VersionMajor 14 `
            -VersionMinor 2 `
            -LocalDVDImageDirectory "ignore" `
            -S3DVDImageDirectory "ignore" `
            -S3VisualLANSAUpdateDirectory "ignore" `
            -S3IntegratorUpdateDirectory "ignore" `
            -AmazonAMIName "Windows_Server-2016-Japanese-Full-SQL_2016_SP2_Express*" `
            -Language 'JPN' `
            -GitBranch "debug/jpn" `
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
