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

try
{
    Write-Output ("$(Log-Date) Starting Windows Update")
    Import-Module $script:IncludeDir\Modules\PSWindowsUpdate
    Get-WUInstall -WindowsUpdate -AutoSelectOnly -Verbose -AutoReboot
} catch {
	$_
    Write-Error ("$(Log-Date) Installation error")
    throw
} finally {
    Write-Output ("$(Log-Date) Finished Windows Update")
}