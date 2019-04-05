<#
.SYNOPSIS

Configure a LANSA Web Server

.EXAMPLE


#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$DBUT='MSSQLS',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$maxconnections = '20',
[String]$userscripthook,
[String]$ApplName = 'LANSA',
[Boolean]$Reset = $true,
[String]$MAXFREE = '9999'
)

# Put first output on a new line in cfn_init log file
Write-Host ("`r`n")

# If environment not yet set up, it should be running locally, not through Remote PS
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

$trusted="NO"

# $DebugPreference = "Continue"
$VerbosePreference = "Continue"

Write-Verbose ("Server_name = $server_name") | Out-Default | Write-Host
Write-Verbose ("DBUT = $DBUT") | Out-Default | Write-Host
Write-Verbose ("dbname = $dbname") | Out-Default | Write-Host
Write-Verbose ("dbuser = $dbuser") | Out-Default | Write-Host
Write-Verbose ("webuser = $webuser") | Out-Default | Write-Host
Write-Verbose ("32bit = $f32bit") | Out-Default | Write-Host
Write-Verbose ("SUDB = $SUDB") | Out-Default | Write-Host
Write-Verbose ("UPGD = $UPGD") | Out-Default | Write-Host
Write-Verbose ("maxconnections = $maxconnections") | Out-Default | Write-Host
Write-Verbose ("ApplName = $ApplName") | Out-Default | Write-Host

try
{

    if ( $f32bit -eq 'true' -or $f32bit -eq '1')
    {
        $f32bit_bool = $true
    }
    else
    {
        $f32bit_bool = $false
    }

    if ( $UPGD -eq 'true' -or $UPGD -eq '1')
    {
        $UPGD_bool = $true
    }
    else
    {
        $UPGD_bool = $false
    }

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\$ApplName"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\$ApplName"
    }

    #####################################################################################
    # Configure Application Server
    #####################################################################################

    Write-Verbose ("64-bit Application Server Settings") | Out-Default | Write-Host
    $lansaKey = "HKLM:\Software\LANSA\C:%5CPROGRAM%20FILES%20(X86)%5C$($ApplName)"
    $lansawebKey = "$lansakey\LANSAWEB"

    if (!(Test-Path -Path $lansakey))
    {
        New-Item -Path $lansaKey -ErrorAction 'Stop'  | Out-Default | Write-Host
        if (!(Test-Path -Path $lansawebkey))
        {
            New-Item -Path $lansawebKey -ErrorAction 'Stop'  | Out-Default | Write-Host
        }
    }

    Write-Host("Disable Session Locking (WAM_SESSION_LOCK) (N)" )
    New-ItemProperty -Path $lansawebKey  -Name WAM_SESSION_LOCK -PropertyType String -Value 'N' -Force  | Out-Null

    Write-Host("Set Maximum Concurrent Users (MAXUSERS) to Unlimited (0)" )
    New-ItemProperty -Path $lansawebKey  -Name MAXUSERS -PropertyType String -Value '0' -Force  | Out-Null

    Write-Host("Log high level Performance Stats (LOG_PERF)" )
    Write-Verbose ("Set to '2' for 2nd level performance log") | Out-Default | Write-Host
    New-ItemProperty -Path $lansawebKey  -Name LOG_PERF -PropertyType String -Value 'Y' -Force  | Out-Null

    Write-Host("Log all performance stats into one log file (LOG_PERF_PER_PROC)" )
    Write-Verbose ("Set to 'Y' for a log file per process rather than 1 log file") | Out-Default | Write-Host
    New-ItemProperty -Path $lansawebKey  -Name LOG_PERF_PER_PROC -PropertyType String -Value 'N' -Force  | Out-Null

    $regkeyname = "FREESLOTS"
    Write-Host("Setting $lansawebKey $RegKeyName Ready To Use Minimum to 1")
    New-ItemProperty -Path $lansawebKey  -Name $regkeyname -Value '1' -PropertyType String -Force  | Out-Null

    $regkeyname = "REUSE"
    Write-Host("Setting $lansawebKey $RegKeyName To 500. That is, terminate web job & restart when it has been used 500 times")
    New-ItemProperty -Path $lansawebKey  -Name $regkeyname -Value '500' -PropertyType String -Force  | Out-Null

    $regkeyname = "MAXFREE"
    Write-Host("Setting $lansawebKey $RegKeyName Ready To Use Maximum to $MAXFREE - this is currently the same value as MAXCONNECT. This is OK as a default but it really needs to be a template parameter. The resources on an instance need to be shared across the 10 applications. So using t2.medium as an example, that supports 20 concurrent jobs so that means 2 jobs per application ( 20 / 10 ) - if all applications are using their maximum allocation. But they won't be generally. For Paid environments where we can tune the settings and educate customers on the effects, then we can 'over-clock' each application to allow EACH to use the maximum that the instance can support. 20 jobs per app in this example. Obviously, this is momentarily. If each used its maximum comcurrently the machine would be 10 times overloaded. So for such a setup MAXCONNECT would be set to the instance maximum - 20 for this example, and MAXFREE set to the status quo value - 2 for this example. Thus up to 20 may be used momentarily, but once they have stopped being used they will be terminated back to 2 jobs. And MAXCONNECT may be tuned up and down as necessary within this range")
    New-ItemProperty -Path $lansawebKey  -Name $regkeyname -Value $MAXFREE -PropertyType String -Force  | Out-Null

    #####################################################################################
    # Change MAXCONNECT to reflect max WAM sessions you want running on a Web Server.
    # i.e webplugin.conf
    # This value is passed from the CloudFormation script and may be changed using a
    # trigger in that script.
    #####################################################################################
    $webplugin_file = (Join-Path -Path $APPA -ChildPath 'Webserver\iisplugin\webplugin.conf')
    if ((Test-Path -Path $webplugin_file)) {
        # web plugin configuration file changed name in V14
        Write-Host ("Using Web Plugin configuration file $webplugin_file")

        Write-Verbose ("Set maximum lcotp sessions to $maxconnections in $webplugin_file") | Out-Default | Write-Host

        Write-Verbose ("Check if MAXCONNECT exists in file at all") | Out-Default | Write-Host

        If (Get-Content $webplugin_file | Select-String -Pattern "MAXCONNECT=") {

            Write-Verbose ("It exists so replace it with user setting") | Out-Default | Write-Host

            (Get-Content $webplugin_file) |
            Foreach-Object {$_ -replace "MAXCONNECT=[0-9]+","MAXCONNECT=$maxconnections"}  |
            Set-Content ($webplugin_file)
        } else {

            Write-Verbose ("Does not exist, append it to file") | Out-Default | Write-Host

            Add-Content $webplugin_file "`nMAXCONNECT=$maxconnections" | Out-Default | Write-Host
        }

        Write-Verbose ("Check if ASSUME_AUTOCONFIG_SUPPORT exists in file at all") | Out-Default | Write-Host

        If (Get-Content $webplugin_file | Select-String -Pattern "ASSUME_AUTOCONFIG_SUPPORT=") {

            Write-Verbose ("It exists so set it to Y") | Out-Default | Write-Host

            (Get-Content $webplugin_file) |
            Foreach-Object {$_ -replace "ASSUME_AUTOCONFIG_SUPPORT=.","ASSUME_AUTOCONFIG_SUPPORT=Y"}  |
            Set-Content ($webplugin_file)
        } else {

            Write-Verbose ("Does not exist, append it to file") | Out-Default | Write-Host

            Add-Content $webplugin_file "`nASSUME_AUTOCONFIG_SUPPORT=Y" | Out-Default | Write-Host
        }

        Write-Host( "Setting Restart Delay to 4 seconds so that an app comes online quicker after a 1-Click deployment")
        (Get-Content $webplugin_file) |
        Foreach-Object {$_ -replace ";60;",";4;"}  |
        Set-Content ($webplugin_file)
    } else {
        Write-Host( "$webplugin_file does not exist. Presumed there is not a plugin running in this system.")
    }

    Write-Host ("Stopping Listener...")
    Write-Verbose ("We only install the 64-bit listener on 64-bit OS") | Out-Default | Write-Host
    if ( $false )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstop" -Wait | Out-Default | Write-Host
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstop" -Wait | Out-Default | Write-Host
    }

    Write-Host ("Stopping all web jobs...")
    Start-Process -FilePath "$APPA\X_Win95\X_Lansa\Execute\w3_p2200.exe" -ArgumentList "*FORINSTALL" -Wait | Out-Default | Write-Host

    Write-Host ("Starting Listener...")
    if ( $false )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstart" -Wait | Out-Default | Write-Host
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstart" -Wait | Out-Default | Write-Host
    }

    if ( $Reset ) {
        Write-Host ("Resetting iis...")
        iis-reset
    }

    Write-Host ("Webconfig completed successfully")
    cmd /c exit 0
}
catch
{
    $_ | Out-Default | Write-Host
    throw "Webconfig failed"
    cmd /c exit 2
}
