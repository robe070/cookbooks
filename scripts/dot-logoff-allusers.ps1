function Logoff-Allusers()
{
    # Check if more than the current user is logged on
    $Computer = $ENV:COMPUTERNAME
    # Redirect stderr to a file otherwise the script displays an error which SilentlyContinue and capturing the exception do not trap.
    [object[]]$sessions = Invoke-Expression "$script:IncludeDir\PsLoggedon.exe /accepteula -x 2>c:\lansa\temp.txt " |
        Where-Object {$_ -match '^\s{2,}(((?<domain>.*)\\(?<user>\S+))|(?<user>\S+))'} |
        Select-Object @{
            Name='Computer'
            Expression={$Computer}
        },
        @{
            Name='Domain'
            Expression={$matches.Domain}
        },
        @{
            Name='User'
            Expression={$Matches.User}
        }

    # Check for >= 2 so we don't logoff the user running the script if they are the only one.
    IF ($Sessions.count -ge 2)
    {
	    # Force Logoff all RDP users so that reboot will work and applying updates less likely to fail 
	    LogWrite 'Forcing logoff of all users'
	
        try
        {
	        $win32OS = get-wmiobject win32_operatingsystem -computername $Computer
	        $win32OS.psbase.Scope.Options.EnablePrivileges = $true
	        $win32OS.win32shutdown(4)

	        # Wait to make sure the users have actually been logged off
	        # Not sure if this makes a difference
	        Start-Sleep -s 10

	        LogWrite 'Users have been logged off'
        }
        catch
        {
            LogWrite 'Attempt to log all users off failed. Presumed to be because no users are logged on'
        }
    }
    else
    {
        LogWrite '1 or less users logged on'
    }
}
