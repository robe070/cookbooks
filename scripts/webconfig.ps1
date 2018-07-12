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
Write-Output ("`r`n")

$trusted="NO"

# $DebugPreference = "Continue"
$VerbosePreference = "Continue"

Write-Verbose ("Server_name = $server_name")
Write-Verbose ("DBUT = $DBUT")
Write-Verbose ("dbname = $dbname")
Write-Verbose ("dbuser = $dbuser")
Write-Verbose ("webuser = $webuser")
Write-Verbose ("32bit = $f32bit")
Write-Verbose ("SUDB = $SUDB")
Write-Verbose ("UPGD = $UPGD")
Write-Verbose ("maxconnections = $maxconnections")
Write-Verbose ("ApplName = $ApplName")

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

    Write-Verbose ("64-bit Application Server Settings")
    $lansaKey = "HKLM:\Software\LANSA\C:%5CPROGRAM%20FILES%20(X86)%5C$($ApplName)"
    $lansawebKey = "$lansakey\LANSAWEB"

    if (!(Test-Path -Path $lansakey))
    {
        New-Item -Path $lansaKey -ErrorAction 'Stop' | format-list
        if (!(Test-Path -Path $lansawebkey))
        {
            New-Item -Path $lansawebKey -ErrorAction 'Stop' | format-list
        }
    }
    Write-Output("Set Maximum Concurrent Users (MAXUSERS) to Unlimited (0)" )
    New-ItemProperty -Path $lansawebKey  -Name MAXUSERS -PropertyType String -Value '0' -Force  | Out-Null

    Write-Output("Log high level Performance Stats (LOG_PERF)" )
    Write-Verbose ("Set to '2' for 2nd level performance log")
    New-ItemProperty -Path $lansawebKey  -Name LOG_PERF -PropertyType String -Value 'Y' -Force  | Out-Null

    Write-Output("Log all performance stats into one log file (LOG_PERF_PER_PROC)" )
    Write-Verbose ("Set to 'Y' for a log file per process rather than 1 log file")
    New-ItemProperty -Path $lansawebKey  -Name LOG_PERF_PER_PROC -PropertyType String -Value 'N' -Force  | Out-Null

    $regkeyname = "FREESLOTS"
    Write-Output("Setting $lansawebKey $RegKeyName Ready To Use Minimum to 1")
    New-ItemProperty -Path $lansawebKey  -Name $regkeyname -Value '1' -PropertyType String -Force  | Out-Null

    $regkeyname = "REUSE"
    Write-Output("Setting $lansawebKey $RegKeyName To 500. That is, terminate web job & restart when it has been used 500 times")
    New-ItemProperty -Path $lansawebKey  -Name $regkeyname -Value '500' -PropertyType String -Force  | Out-Null

    $regkeyname = "MAXFREE"
    Write-Output("Setting $lansawebKey $RegKeyName Ready To Use Maximum to 2 - this needs to be configurable from the template parameters. Its appropriate for PaaS becasue 10 apps are sharing 1 Plugin which must be set MAXCONNECT=20 because thats what a t2.medium can support. But, the Plugin allows 20 PER APPLICATIONS SERVER. Hence with 10 app servers thats a potential for 200 jobs when the machine can handle only 20. So, idle jobs need to be terminated. Setting this to 2 ensures we won't keep more than 20 running unless more than 2 are active for an app server.")
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
        Write-Output ("Using Web Plugin configuration file $webplugin_file")

        Write-Verbose ("Set maximum lcotp sessions to $maxconnections in $webplugin_file")

        Write-Verbose ("Check if MAXCONNECT exists in file at all")

        If (Get-Content $webplugin_file | Select-String -Pattern "MAXCONNECT=") {
            
            Write-Verbose ("It exists so replace it with user setting")

            (Get-Content $webplugin_file) |
            Foreach-Object {$_ -replace "MAXCONNECT=[0-9]+","MAXCONNECT=$maxconnections"}  | 
            Set-Content ($webplugin_file)
        } else {
            
            Write-Verbose ("Does not exist, append it to file")

            Add-Content $webplugin_file "`nMAXCONNECT=$maxconnections"
        }

        Write-Output( "Setting Restart Delay to 4 seconds so that an app comes online quicker after a 1-Click deployment")
        (Get-Content $webplugin_file) |
        Foreach-Object {$_ -replace ";60;",";4;"}  | 
        Set-Content ($webplugin_file)
    } else {
        Write-Output( "$webplugin_file does not exist. Presumed there is not a plugin running in this system.")
    }
    
    Write-Output ("Stopping Listener...")
    Write-Verbose ("We only install the 64-bit listener on 64-bit OS")
    if ( $false )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstop" -Wait
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstop" -Wait
    }

    Write-Output ("Stopping all web jobs...")
    Start-Process -FilePath "$APPA\X_Win95\X_Lansa\Execute\w3_p2200.exe" -ArgumentList "*FORINSTALL" -Wait

    Write-Output ("Starting Listener...")
    if ( $false )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstart" -Wait
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstart" -Wait
    }

    if ( $Reset ) {
        Write-Output ("Resetting iis...")
        iisreset
        # Do it twice as sometimes the first fails as it takes too long when there are 11 applications installed and managed by 1 plugin.
        iisreset
    }

    Write-Output ("Webconfig completed successfully")
    cmd /c exit 0
}
catch
{
    $_
    throw "Webconfig failed"
    cmd /c exit 2
}
