$S3DVDImageDirectory = "s3://lansa/releasedbuilds/v14/LanDVDcut_L4W14000_latest"
$SQLServerInstalled = $false

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
    cmd /c aws s3 sync  $S3DVDImageDirectory $Script:DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--delete" | Write-Output
} else {
    cmd /c aws s3 sync  $S3DVDImageDirectory $Script:DvdDir "--exclude" "*ibmi/*" "--exclude" "*AS400/*" "--exclude" "*linux/*" "--exclude" "*setup/Installs/MSSQLEXP/*" "--delete" | Write-Output
}

New-Shortcut "$ENV:SystemRoot\system32\WindowsPowerShell\v1.0\powershell.exe" "Desktop\After IDE Installed.lnk" -Description "Install EPCs" -Arguments "-ExecutionPolicy Bypass -Command ""c:\lansa\Scripts\post-base-boot.ps1"""
