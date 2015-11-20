param (
    [Parameter(Mandatory=$true)]
    [string]
    $S3DVDImageDirectory,

    [Parameter(Mandatory=$true)]
    [string]
    $DvdDir,

    [Parameter(Mandatory=$true)]
    [string]
    $SQLServerInstalled
)

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

Write-Output "$(Log-Date) S3DVDImageDirectory = $S3DVDImageDirectory, DvdDir = $DvdDir"

if ( $SQLServerInstalled -eq $false) {
    cmd /c aws s3 sync  $S3DVDImageDirectory $DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--delete" | Write-Output
} else {
    cmd /c aws s3 sync  $S3DVDImageDirectory $DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--exclude" "*setup/Installs/MSSQLEXP/*" "--delete" | Write-Output
}
