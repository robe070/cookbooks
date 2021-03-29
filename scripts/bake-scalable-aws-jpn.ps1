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

Bake-IdeMsi -VersionText 'w16jpn' `
            -VersionMajor 1 `
            -VersionMinor 0 `
            -LocalDVDImageDirectory "ignore" `
            -S3DVDImageDirectory "ignore" `
            -S3VisualLANSAUpdateDirectory "ignore" `
            -S3IntegratorUpdateDirectory "ignore" `
            -AmazonAMIName "Windows_Server-2016-Japanese-Full-SQL_2016_SP2_Express*" `
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
