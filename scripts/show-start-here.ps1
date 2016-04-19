<#
.SYNOPSIS

Show the LANSA Start Here page the first time the virtual machine is started.

.DESCRIPTION

The HKLM\Software\Microsoft\Windows\CurrentVersion\RunOnce key should be the one used but it is run
BEFORE the user has a desktop!

So HKLM\Software\Microsoft\Windows\CurrentVersion\Run key needs to be used as it IS displayed once the user has a desktop!
The Run key must not be deleted by the script on recommendation from Microsoft. 
So to show it only once a registry key is used. 

Note that script execution must be enabled before sysprep is done
i.e. Set-ExecutionPolicy RemoteSigned

.EXAMPLE

#>

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

if(-not ((Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'StartHereShown' -ErrorAction SilentlyContinue).StartHereShown)) {
    # Enable Video in Internet Explorer. Note that the VM will fail to sysprep with this set.
    # To be able to sysprep, delete the HKCU entries referred to in the following file
    & reg import "$Script:GitRepoPath\scripts\VideoEnable.reg"

    start-process "$ENV:ProgramFiles\Internet Explorer\iexplore.exe" "$ENV:ProgramFiles\CloudStartHere.htm"


    New-ItemProperty -Path HKLM:\Software\LANSA -Name StartHereShown -PropertyType DWord -Value $true –Force | Out-Null

    Write-Output "Finished"
} else {
    Write-Output "Already ran"
}