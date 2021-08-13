if ( -not $script:IncludeDir)
{
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Host "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else
{
	Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

$Language = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Language').Language
Write-Host ("$(Log-Date) Language = $Language")

$Platform = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Platform').Platform
Write-Host ("$(Log-Date) Running on $Platform")

& "$script:IncludeDir\language-pack-config-2.ps1" $Language  $Platform