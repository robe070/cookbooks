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

Bake-IdeMsi -VersionText '14.2 EPC142010' `
            -VersionMajor 14 `
            -VersionMinor 2 `
            -LocalDVDImageDirectory "" `
            -S3DVDImageDirectory "" `
            -S3VisualLANSAUpdateDirectory "" `
            -S3IntegratorUpdateDirectory "" `
            -AmazonAMIName "Windows_Server-2016-English-Full-SQL_2017_Express*" `
            -GitBranch "support/L4W14200_scalable"`
            -InstallBaseSoftware $true `
            -InstallSQLServer $false `
            -InstallIDE $false `
            -InstallScalable $true `
            -Win2012 $false
