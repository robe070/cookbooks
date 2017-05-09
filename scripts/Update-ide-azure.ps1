<#
.SYNOPSIS

Bake an Upgrade to a LANSA Azure Image

.DESCRIPTION

.EXAMPLE


#>

# Azure debug messages are extremely verbose so ensure they are switched off
$DebugPreference = "ContinueSilently"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"
. "$Script:IncludeDir\bake-ide-ami.ps1"

# set up environment if not yet setup
if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Output "$(Log-Date) Environment already initialised"
}

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest

$Win2012 = $true

# To update the last image. put -VersionText image in -AmazonAMIName and increment the last digit by 1
# so if VersionText = 'IDESQL-F3', then it becomes 'IDESQL-F4' & AmazonAMIName becomes 'IDESQL-F3image'

Bake-IdeMsi -VersionText 'IDESQL-F3' `
            -VersionMajor 14 `
            -VersionMinor 1 `
            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\CloudOnly\SPIN0334_LanDVDcut_L4W14100_4138_160727_EPC1410xx" `
            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
            -AmazonAMIName 'IDESQL-F2image' `
            -GitBranch "support/L4W14100_IDE"`
            -Cloud "Azure" `
            -InstallBaseSoftware $false `
            -InstallSQLServer $false `
            -InstallIDE $true `
            -InstallScalable $false `
            -Win2012 $Win2012 `
            -SkipSlowStuff $false `
            -Upgrade $true

Write-Host "$(Log-Date) AMI Update complete"