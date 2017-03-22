<#
.SYNOPSIS

Download the LANSA IDE installation media for Windows 
(That is, its omits Linux and IBM i parts of the original distribution)


#>
param(
    [String] $S3DVDImageDirectory = 's3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest'
)

# If environment not yet set up, it should be running locally, not through Remote PS
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
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

try
{
    $DebugPreference = "Continue"
    $VerbosePreference = "Continue"

    #####################################################################################
    Write-Output ("$(Log-Date) Pull down DVD image ")
    #####################################################################################
    $DvdDir = 'c:\LanDVDCut'
    cmd /c mkdir $DvdDir '2>nul'

    cmd /c aws s3 sync  $S3DVDImageDirectory $DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--exclude" "*setup/Installs/MSSQLEXP/*" "--delete" | Write-Output
    if ( $LastExitCode -ne 0 )
    {
        throw
    }

    Write-Output ("$(Log-Date) Download completed successfully")
}
catch
{
	$_
    Write-Error ("$(Log-Date) Installation error")
    throw
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
