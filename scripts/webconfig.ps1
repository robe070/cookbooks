<#
.SYNOPSIS

Configure a LANSA Web Server

.EXAMPLE


#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$f32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false',
[String]$maxconnections = '20',
[String]$userscripthook
)

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

$trusted="NO"

# $DebugPreference = "Continue"
# $VerbosePreference = "Continue"

Write-Debug ("Server_name = $server_name")
Write-Debug ("dbname = $dbname")
Write-Debug ("dbuser = $dbuser")
Write-Debug ("webuser = $webuser")
Write-Debug ("32bit = $f32bit")
Write-Debug ("SUDB = $SUDB")
Write-Debug ("UPGD = $UPGD")
Write-Debug ("maxconnections = $maxconnections")

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
        $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\LANSA"
    }

    #####################################################################################
    # Configure maximum users
    #####################################################################################

    if ( $f32bit_bool )
    {
        Write-Verbose ("32-bit MAXUSERS=9999")
        $lansawebKey = 'HKLM:\Software\wow6432node\LANSA\C:%5CPROGRAM%20FILES%20(X86)%5CLANSA\LANSAWEB'
        if (!(Test-Path -Path $lansawebkey))
        {
            New-Item -Path $lansawebKey
        }
        New-ItemProperty -Path $lansawebKey  -Name MAXUSERS -PropertyType String -Value '9999' -Force
        # Set to '2' for 2nd level performance log
        New-ItemProperty -Path $lansawebKey  -Name LOG_PERF -PropertyType String -Value 'N' -Force
        # Set to 'Y' for a log file per process rather than 1 log file
        New-ItemProperty -Path $lansawebKey  -Name LOG_PERF_PER_PROC -PropertyType String -Value 'N' -Force
    }
    else
    {
        Write-Verbose ("64-bit MAXUSERS=9999")
        $lansawebKey = 'HKLM:\Software\LANSA\C:%5CPROGRAM%20FILES%20(X86)%5CLANSA\LANSAWEB'
        if (!(Test-Path -Path $lansawebkey))
        {
            New-Item -Path $lansawebKey
        }
        New-ItemProperty -Path $lansawebKey  -Name MAXUSERS -PropertyType String -Value '9999' -Force
        New-ItemProperty -Path $lansawebKey  -Name LOG_PERF -PropertyType String -Value 'N' -Force
        New-ItemProperty -Path $lansawebKey  -Name LOG_PERF_PER_PROC -PropertyType String -Value 'N' -Force
    }

    #####################################################################################
    # Change MAXCONNECT to reflect max WAM sessions you want running on a Web Server. 
    # i.e l4w3serv.cfg
    # This value is passed from the CloudFormation script and may be changed using a
    # trigger in that script.
    #####################################################################################

    $l4w3serv_file = (Join-Path -Path $APPA -ChildPath 'Webserver\iisplugin\l4w3serv.cfg')
    $l4w3serv_default_file = (Join-Path -Path $APPA -ChildPath 'Webserver\iisplugin\l4w3serv_factory_default.cfg')
    Write-Verbose ("Set maximum lcotp sessions to $maxconnections in $l4w3serv_file")

    # Either save the installed file as the default, or if the default exists, restore the installed file.
    # Thus we have a consistent starting point.
    if ( !(Test-Path -Path $l4w3serv_default_file) )
    {
        Write-Verbose ("Save default config file $l4w3serv_default_file")

        copy-item -Path $l4w3serv_file -Destination ( $l4w3serv_default_file )
    }
    else
    {
        copy-item -Path $l4w3serv_default_file -Destination ( $l4w3serv_file )
    }

    Write-Verbose ("Set MAXCONNECT to $maxconnections")

    (Get-Content $l4w3serv_file) |
    Foreach-Object {$_ -replace "MAXCONNECT=[0-9]+","MAXCONNECT=$maxconnections"}  | 
    Set-Content ($l4w3serv_file)

    #####################################################################################
    # Switch off "Transform XSLT on WebServer" - LANSA;XHTML;N;yes;N;0;Y;yes;Y to LANSA;XHTML;N;yes;N;0;Y;yes;N
    #####################################################################################
    #(Get-Content $l4w3serv_file) |
    #Foreach-Object {$_ -replace "LANSA;XHTML;N;yes;N;0;Y;yes;Y","LANSA;XHTML;N;yes;N;0;Y;yes;N"}  | 
    #Set-Content ($l4w3serv_file)

    #####################################################################################
    # Change max WAM sessions you want running for the Web Site. 
    # i.e l4w3serv.cfg - look for N;100. Change to Y;<your value>
    #####################################################################################

    if ( 0 )
    {
        $l4w3serv_file = (Join-Path -Path $APPA -ChildPath 'Webserver\iisplugin\l4w3serv.cfg')
        $l4w3serv_default_file = (Join-Path -Path $APPA -ChildPath 'Webserver\iisplugin\l4w3serv_factory_default.cfg')
        Write-Verbose ("Set maximum lcotp sessions to $maxconnections in $l4w3serv_file")

        # Either save the installed file as the default, or if the default exists, restore the installed file.
        # Thus we have a consistent starting point.
        if ( !(Test-Path -Path $l4w3serv_default_file) )
        {
            Write-Verbose ("Save default config file $l4w3serv_default_file")

            copy-item -Path $l4w3serv_file -Destination ( $l4w3serv_default_file )
        }
        else
        {
            copy-item -Path $l4w3serv_default_file -Destination ( $l4w3serv_file )
        }

        Write-Verbose ("Replace N;100;-; with Y;$maxconnections;-;")

        (Get-Content $l4w3serv_file) |
        Foreach-Object {$_ -replace 'N;100;-;',"Y;$maxconnections;-;"}  | 
        Set-Content ($l4w3serv_file)
    }

    Write-Verbose ("Stopping Listener...")
    if ( $f32bit_bool )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstop" -Wait
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstop" -Wait
    }


    Write-Verbose ("Stopping all web jobs...")
    Start-Process -FilePath "$APPA\X_Win95\X_Lansa\Execute\w3_p2200.exe" -ArgumentList "*FORINSTALL" -Wait

    Write-Verbose ("Resetting iis...")
    iisreset

    Write-Verbose ("Starting Listener...")
    if ( $f32bit_bool )
    {
        Start-Process -FilePath "$APPA\connect\lcolist.exe" -ArgumentList "-sstart" -Wait
    }
    else
    {
        Start-Process -FilePath "$APPA\connect64\lcolist.exe" -ArgumentList "-sstart" -Wait
    }
    
    Write-Output ("Webconfig completed successfully")
    cmd /c exit 0
}
catch
{
    Write-Error ("Webconfig failed")
    cmd /c exit 2
}
