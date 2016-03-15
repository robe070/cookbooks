<#
.SYNOPSIS

Install the French Base environment.
Required because
This cannot be executed remotely. It must be executed directly on the machine, for French. ENG and JPN are fine!
   C:\Windows\system32\dism.exe /online /enable-feature /featurename:IIS-NetFxExtensibility /norestart  /All 


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

try
{
    #####################################################################################
    Write-Output ("$(Log-Date) Installing IIS-NetFxExtensibility")

    C:\Windows\system32\dism.exe /online /enable-feature /featurename:IIS-NetFxExtensibility /norestart  /All

    Write-Output ("$(Log-Date) French Base installation completed successfully")
    # Successful completion so set Last Exit Code to 0
    cmd /c exit 0
}
catch
{
	$_
    Write-Error ("$(Log-Date) French Base installation error")
    throw
}
