# Includes
. "$script:IncludeDir\dot-logoff-allusers.ps1"
. "$script:IncludeDir\dot-check-restart.ps1"
. "$script:IncludeDir\dot-logwrite.ps1"

# Check for restart in case reboot not detected or a prior need for reboot has failed
# e.g. due to logged on users.
function Restart-IfNeeded()
{
	[bool]$restart = $false
	Check-Restart( [REF]$restart)
	if ( $restart )
	{
		Logoff-Allusers

		LogWrite "Restart required - Restarting..."
		Restart-Computer -Force
	}
	else
	{
		LogWrite "Restart not required"
		Write-Output "Restart not required (2)"
	}
}