function Logoff-Allusers()
{
	# Force Logoff all RDP users so that reboot will work and applying updates less likely to fail 
	LogWrite 'Forcing logoff of all users'
	
	$win32OS = get-wmiobject win32_operatingsystem -computername $ENV:COMPUTERNAME
	$win32OS.psbase.Scope.Options.EnablePrivileges = $true
	$win32OS.win32shutdown(4)

	# Wait to make sure the users have actually been logged off
	# Not sure if this makes a difference
	Start-Sleep -s 10

	LogWrite 'Users have been logged off'
}
