<#
.SYNOPSIS

Install a LANSA MSI.
Creates a SQL Server Database then installs the MSI

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules.
E.g. The password is sufficiently complex and the userid is not duplicated in the password.
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

.EXAMPLE

1. Upload msi to c:\lansa\MyApp.msi (Copy file from local machine. Paste into RDP session)
2. Start SQL Server Service and set to auto start. Change SQL Server to accept SQL Server Authentication
3. Create lansa database
4. Add user lansa with password 'Pcxuser@122' to SQL Server as Sysadmin and to the lansa database as dbowner
5. Change server_name to the machine name in this command line and run it:
C:\\LANSA\\scripts\\install-lansa-msi.ps1 -server_name "IP-AC1F2F2A" -dbname "lansa" -dbuser "lansa" -dbpassword "Pcxuser@122" -webuser "pcxuser" -webpassword "Lansa@122"

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
[String]$wait,
[String]$userscripthook,
[Parameter(Mandatory=$false)]
[String]$DBUT='MSSQLS',
[String]$MSIuri,
[String]$trace = 'N',
[String]$traceSettings = "ITRO:Y ITRL:4 ITRM:9999999999",
[String]$ApplName = "LANSA",
[String]$CompanionInstallPath = "",
[String]$HTTPPortNumber = "",
[String]$HostRoutePortNumber = "",
[String]$JSMPortNumber = "",
[String]$JSMAdminPortNumber = "",
[String]$HTTPPortNumberHub = "",
[String]$GitRepoUrl = "",
[String]$GitRepoBranch = "",
[Boolean]$DisableSQLServer = $true
)

function Test-RegistryValue {
    param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path,

        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Value
    )

    try {
        Get-ItemProperty -Path $Path | Select-Object -ExpandProperty $Value -ErrorAction Stop | Out-Null
        return $true
    } catch {
        return $false
    }

}

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

# Put first output on a new line in cfn_init log file
Write-Host ("`r`n")

$DebugPreference = "SilentlyContinue"
$ProgressPreference = "SilentlyContinue" # Speeds up some cmdlets
$VerbosePreference = "Continue"
[String]$trusted = "NO"

Write-Verbose ("Server_name = $server_name") | Out-Default | Write-Host
Write-Verbose ("dbname = $dbname") | Out-Default | Write-Host
Write-Verbose ("dbuser = $dbuser") | Out-Default | Write-Host
Write-Verbose ("webuser = $webuser") | Out-Default | Write-Host
Write-Verbose ("32bit = $f32bit") | Out-Default | Write-Host
Write-Verbose ("SUDB = $SUDB") | Out-Default | Write-Host
Write-Verbose ("UPGD = $UPGD") | Out-Default | Write-Host
Write-Verbose ("DBUT = $DBUT") | Out-Default | Write-Host
Write-Verbose ("Password = $dbpassword") | Out-Default | Write-Host
Write-Verbose ("ApplName = $ApplName") | Out-Default | Write-Host
Write-Verbose ("CompanionInstallPath = $CompanionInstallPath") | Out-Default | Write-Host
Write-Verbose ("Wait Handle = $Wait") | Out-Default | Write-Host

try
{
    $ExitCode = 0
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

    Write-Debug ("$(Log-Date) UPGD_bool = $UPGD_bool" ) | Out-Default | Write-Host

    $temp_out = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install.log )
    $temp_err = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install_err.log )

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    Write-Verbose ("$(Log-Date) Running on $Cloud")

    [boolean]$CompanionInstall = $false

    if ( $CompanionInstallPath.Length -gt 0) {
        if ( -not (test-path $CompanionInstallPath)) {
            Write-Error ("CompanionInstallPath '$CompanionInstallPath' does not exist")
            throw ("CompanionInstallPath '$CompanionInstallPath' does not exist")
        }
        $CompanionInstall = $true
    }

    $InstallDir = Join-Path $(Split-Path -Parent $script:IncludeDir) "Installs\VC_Redist"
    if (Test-Path $InstallDir) {
        Write-Host( "$(Log-Date) Installs directory = $InstallDir" )
    } else {
        throw "Installs directory $InstallDir does not exist"
    }

    if ($true) {
        # On initial install

        if ( (-not $CompanionInstall) -and (-not $UPGD_bool) -and ($Cloud -ne "Docker") -and ($Cloud -ne "on-premise") ) {
            Write-Host ("$(Log-Date) Disable TCP Offloading" )
            Disable-TcpOffloading

            # When installing through cloudformation the current user is systemprofile.
            # When GitDeployHub receives a webhook it may be running as administrator

            Write-Host ("$(Log-Date) Add github.com to known_hosts for current user and for Administrator" )
            $KnownHostsDir = "$ENV:USERPROFILE\.ssh"
            if ( -not (test-path $KnownHostsDir)) {
                mkdir $KnownHostsDir
            }
            Set-AccessControl "Everyone" $KnownHostsDir "ReadAndExecute, Synchronize" "ContainerInherit, ObjectInherit"
            Get-Content "$script:IncludeDir\github.txt" | out-file  "$KnownHostsDir\known_hosts" -Append -encoding utf8

            # If there is an adminstrator user, create the known hosts there too.
            $KnownHostsDir = "c:\users\administrator"
            if ( (test-path $KnownHostsDir)) {
                $KnownHostsDir = "$KnownHostsDir\.ssh"
                if ( -not (test-path $KnownHostsDir)) {
                    mkdir $KnownHostsDir
                }
                Set-AccessControl "Everyone" $KnownHostsDir "ReadAndExecute, Synchronize" "ContainerInherit, ObjectInherit"
                Get-Content "$script:IncludeDir\github.txt" | out-file  "$KnownHostsDir\known_hosts" -Append -encoding utf8
            }

            Write-Host ("$(Log-Date) Open Windows Firewall for HTTP ports...")
            Write-Host ("$(Log-Date) Note that these port numbers are what has been specified on the command line. If they are in use the LANSA Install will find the next available port and use that. So, strictly, should really pick up the port number after the lansa install has been run from the web site itself. For now, we know the environment as its a cloud image that we build.")
            if ( $HTTPPortNumber.Length -gt 0 -and $HTTPPortNumber -ne "80") {
                New-NetFirewallRule -DisplayName 'LANSA HTTP Inbound'-Direction Inbound -Action Allow -Protocol TCP -LocalPort @("$HTTPPortNumber")
            }
            if ( $HTTPPortNumberHub.Length -gt 0) {
                New-NetFirewallRule -DisplayName 'GitDeployHub Inbound'-Direction Inbound -Action Allow -Protocol TCP -LocalPort @("$HTTPPortNumberHub")
            }

            Write-Host "$(Log-Date) Install Visual C Runtime 32-bit for VS 2015, 2017, 2019"
            start-process -FilePath "$InstallDir\vcredist_x86.exe" -ArgumentList '/install', '/quiet', '/norestart' -Wait

            Write-Host "$(Log-Date) Install Visual C Runtime 64-bit for VS 2015, 2017, 2019"
            start-process -FilePath "$InstallDir\vcredist_x64.exe" -ArgumentList '/install', '/quiet', '/norestart' -Wait
        }

        # ***********************************************************************************
        if ( (-not $CompanionInstall -and $DisableSQLServer ) ) {
            Write-Host( "$(Log-Date) Disable SQL Server service so it doesn't randomly start up" )

            # Check if SQL Server is installed
            $mssql_services = @(Get-WmiObject win32_service | where-object name -like 'MSSQL*')
            If ( $mssql_services.count -ne 0  ) {
                if ( $mssql_services.Count -ne 1) {
                    $ServiceName = "MSSQLSERVER"
                } else {
                    $ServiceName = $mssql_services[0].Name
                }
                $service = @(get-service $ServiceName)
                $count = $($service | Measure-Object).Count
                if ( $Count -ne 1 ) {
                    $service  | Format-Table Name, DisplayName, Status, StartType, DependentServices, ServicesDependedOn | Out-Host
                    throw "Should only be one $ServiceName service"
                }
                stop-service $service[0] -Force | Out-Default | Write-Host
                set-service $ServiceName -StartupType Disabled | Out-Default | Write-Host

                @(get-service $ServiceName) | Format-Table Name, DisplayName, Status, StartType, DependentServices, ServicesDependedOn | Out-Host
            }
        }
        # ***********************************************************************************

        $installer = "$($ApplName).msi"

        $installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
        $install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "$($ApplName).log" )

        # Docker passes in a local path to the MSI which is mapped to a host volume
        # Just copy it to the standard name - its used to determine if an upgrade or not.
        # if ( $Cloud -eq "Docker") {
        #     Copy-Item -Path $MSIUri -Destination $installer_file -Force | Out-Default | Write-Host
        # }

        # if ( $MSIuri.Length -gt 0 -and ($Cloud -eq "Azure" -or ($Cloud -eq "AWS") -or ($Cloud -eq "on-premise")) ) {
        if ( $MSIuri.Length -gt 0 ) {
            Write-Verbose ("$(Log-Date) Downloading $MSIuri to $installer_file") | Out-Default | Write-Host
            $downloaded = $false
            $TotalFailedDownloadAttempts = 0
            $Item = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -ErrorAction SilentlyContinue
            If ( $Item ) {
                Write-Verbose "$(Log-Date) TotalFailedDownloadAttempts registry value Found"
                $TotalFailedDownloadAttempts = $item.TotalFailedDownloadAttempts
            }
            $loops = 0
            while (-not $Downloaded -and ($Loops -le 10) ) {
                try {
                    Write-Host ("$(Log-Date) Attempting download")
                    (New-Object System.Net.WebClient).DownloadFile($MSIuri, $installer_file) | Out-Default | Write-Host
                    $downloaded = $true
                } catch {
                    $TotalFailedDownloadAttempts += 1
                    New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -Value ($TotalFailedDownloadAttempts) -PropertyType DWORD -Force | Out-Null
                    $loops += 1

                    Write-Host ("$(Log-Date) Total Failed Download Attempts = $TotalFailedDownloadAttempts")

                    if ($loops -gt 10) {
                        throw "Failed to download $MSIuri from S3"
                    }

                    # Pause for 30 seconds. Maybe that will help it work?
                    Start-Sleep 30
                }
            }

        }

        $DownloadODBCDriver = $true
        if ( (-not $CompanionInstall) ) {
            if (  ($Cloud -eq "AWS"  -or $Cloud -eq "Azure"  -or $Cloud -eq "Docker") ) {
                # ODBC Driver originally installed due to SQLAZURE driver needing to be updated because of C00001A5 exceptions caused by SqlDriverConnect
                Write-Host ("$(Log-Date) Checking ODBC driver for Database Type $DBUT")

                switch -regex ($DBUT) {
                    "SQLAZURE|MSSQL" {
                        $DRIVERURL = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/msodbcsqlx64.msi"
                        [String[]] $Arguments = @( "/quiet", "/lv*x $( Join-Path -Path $ENV:TEMP -ChildPath "odbc.log" )", "IACCEPTMSODBCSQLLICENSETERMS=YES")
                    }
                    "MYSQL" {
                        $DRIVERURL32 = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-win32.msi"
                        $DRIVERURL = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-winx64.msi"
                        [String[]] $Arguments = @( "/quiet")
                    }
                    "ODBCORACLE" {
                        $DRIVERURL32 = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-win32.msi"
                        $DRIVERURL = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-winx64.msi"
                        [String[]] $Arguments = @( "/quiet")
                    }
                    default {
                        $ExitCode = 2
                        $ErrorMessage = "Database Type $DBUT not supported. Requires an ODBC driver to be installed by this script"
                        Write-Error $ErrorMessage -Category NotInstalled
                        throw $ErrorMessage
                    }
                }
            } else {
                # ODBC Driver originally installed due to SQLAZURE driver needing to be updated because of C00001A5 exceptions caused by SqlDriverConnect
                Write-Host ("$(Log-Date) Checking ODBC driver for Database Type $DBUT")

                switch -regex ($DBUT) {
                    "SQLAZURE|MSSQL" {
                        Write-Host( "$(Log-Date) $DBUT ODBC Driver presumed already installed on $Cloud")
                        $DownloadODBCDriver = $false
                    }
                    "MYSQL" {
                        $DRIVERURL32 = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-win32.msi"
                        $DRIVERURL = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-winx64.msi"
                        [String[]] $Arguments = @( "/quiet")
                    }
                    "ODBCORACLE" {
                        $DRIVERURL32 = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-win32.msi"
                        $DRIVERURL = "https://lansa.s3.ap-southeast-2.amazonaws.com/3rd+party/mysql-connector-odbc-winx64.msi"
                        [String[]] $Arguments = @( "/quiet")
                    }
                    default {
                        $ExitCode = 2
                        $ErrorMessage = "Database Type $DBUT not supported. Requires an ODBC driver to be installed by this script"
                        Write-Error $ErrorMessage -Category NotInstalled
                        throw $ErrorMessage
                    }
                }
            }
            if ( $DownloadODBCDriver ) {
                $odbc_installer_file = ( Join-Path -Path $ENV:TEMP -ChildPath "odbc_driver.msi" )
                $odbc_installer_file32 = ( Join-Path -Path $ENV:TEMP -ChildPath "odbc_driver32.msi" )
                Write-Verbose ("$(Log-Date) Downloading $DRIVERURL to $odbc_installer_file") | Out-Default | Write-Host
                (New-Object System.Net.WebClient).DownloadFile($DRIVERURL, $odbc_installer_file) | Out-Default | Write-Host

                $p = Start-Process -FilePath $odbc_installer_file -ArgumentList $Arguments -Wait -PassThru
                if ( $p.ExitCode -ne 0 ) {
                    $ExitCode = $p.ExitCode
                    $ErrorMessage = "ODBC Install returned error code $($p.ExitCode)."
                    Write-Error $ErrorMessage -Category NotInstalled
                    throw $ErrorMessage
                }

                if ( (test-path variable:\DRIVERURL32) ) {
                    Write-Verbose ("$(Log-Date) Downloading $DRIVERURL32 to $odbc_installer_file32") | Out-Default | Write-Host
                    (New-Object System.Net.WebClient).DownloadFile($DRIVERURL32, $odbc_installer_file32)

                    $p = Start-Process -FilePath $odbc_installer_file32 -ArgumentList $Arguments -Wait -PassThru
                    if ( $p.ExitCode -ne 0 ) {
                        $ExitCode = $p.ExitCode
                        $ErrorMessage = "ODBC Install 32 returned error code $($p.ExitCode)."
                        Write-Error $ErrorMessage -Category NotInstalled
                        throw $ErrorMessage
                    }
                }
            }
        }

        if ($Cloud -ne "Docker") {
            #########################################################################################################
            # Database setup
            # Microsoft introduced a defect on 27/10/2016 whereby this code abended when used with Azure SQL Database
            # The template creates the database so it was conditioned out.
            #########################################################################################################

            if ( $dbuser -and $dbuser -ne "" -and $dbpassword -and $dbpassword -ne "") {
                Write-Host( "$(Log-Date) Using SQL Authentication")
                $trusted="NO"
            } else {
                Write-Host( "$(Log-Date) Using trusted connection")
                $trusted="1"
            }

            if ( ($SUDB -eq '1') -and (-not $UPGD_bool) )
            {
                switch ($DBUT) {
                    "MSSQLS" {
                        Write-Host ("$(Log-Date) Database Setup work...")

                        Write-Host ("$(Log-Date) Ensure SQL Server Powershell module is loaded.")

                        Write-Verbose ("$(Log-Date) Loading this module changes the current directory to 'SQLSERVER:\'. It will need to be changed back later") | Out-Default | Write-Host

                        Import-Module “sqlps” -DisableNameChecking | Out-Null

                        if ( $SUDB -eq '1' -and -not $UPGD_bool)
                        {
                            if ( $trusted -eq "NO" ) {
                                Create-SqlServerDatabase $server_name $dbname $dbuser $dbpassword | Out-Default | Write-Host
                            } else {
                                Create-SqlServerDatabase $server_name $dbname | Out-Default | Write-Host
                            }
                        }

                        Write-Verbose ("$(Log-Date) Change current directory from 'SQLSERVER:\' back to the file system so that file pathing works properly") | Out-Default | Write-Host
                        cd "c:"
                    }
                    default {
                        Write-Host ("$(Log-Date) Database presumed to exist")
                    }
                }
            }
        }

        if ( -not $CompanionInstall ) {
            if ( -not $UPGD_bool )
            {
                Start-WebAppPool -Name "DefaultAppPool" | Out-Default | Write-Host
            }

            # The docker operator can easily set command line variables when creating the container, so get out of the way!
            if ( $Cloud -ne 'Docker') {

                Write-Host ("$(Log-Date) Setup tracing for both this process and its children and any processes started after the installation has completed.")

                if ($trace -eq "Y") {
                    [Environment]::SetEnvironmentVariable("X_RUN", $traceSettings, "Machine") | Out-Default | Write-Host
                    $env:X_RUN = $traceSettings
                } else {
                    [Environment]::SetEnvironmentVariable("X_RUN", $null, "Machine") | Out-Default | Write-Host
                    $env:X_RUN = ''
                }
            }
        }

        Write-Host ("$(Log-Date) Installing the application")

        if ($f32bit_bool)
        {
            $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
        }
        else
        {
            $APPA = "${ENV:ProgramFiles}\$($ApplName)"
        }

        if ( -not $CompanionInstall ) {
            New-ItemProperty -Path 'HKLM:\\Software\\LANSA'  -Name MainAppInstallPath -Value $APPA -PropertyType String -Force | Out-Default | Write-Host
        }

        if ( $CompanionInstall ) {
            Write-Host( "$(Log-Date) Kill any msiexec.exe that are still hanging around and haven't been fully ended by Windows so that this install starts ok. Fixes MSI return code 1618.")

            $Processes = @(Get-Process | Where-Object {$_.Path -like "*\msiexec.exe" })
            foreach ($process in $processes ) {
                Write-Host("$(Log-Date) Stopping $($Process.ProcessName)")
                Stop-Process $process.id -Force | Out-Default | Write-Host
            }

            $TotalWait = 0
            do {
                Start-Sleep -Seconds 2
                $TotalWait += 2
                $Processes = @(Get-Process | Where-Object {$_.Path -like "*\msiexec.exe" })
            } while ($Processes.Count -gt 0 -and ($TotalWait -lt 120) )
            Write-Host("$(Log-Date) Waited $TotalWait seconds for msiexec.exe to be terminated. Maximum wait 120 seconds")
        }


        [String[]] $Arguments = @( "/quiet /lv*x $install_log", "SHOWCODES=1", "USEEXISTINGWEBSITE=1", "REQUIRES_ELEVATION=1", "DBUT=$DBUT", "DBII=$($ApplName)", "DBSV=$server_name", "DBAS=$dbname", "TRUSTED_CONNECTION=$trusted", "SUDB=$SUDB",  "USERIDFORSERVICE=$webuser", "PASSWORDFORSERVICE=$webpassword")

        # Arguments to pass only if they have a value
        if ( $CompanionInstallPath.Length -gt 0) {
            $Arguments += "COMPANIONINSTALLPATH=`"$CompanionInstallPath`""
        }

        if ( $trusted -eq "NO" ) {
            $Arguments += @("DBUS=$dbuser", "PSWD=$dbpassword")
        }

        if ( $HTTPPortNumber.Length -gt 0) {
            $Arguments += "HTTPPORTNUMBER=$HTTPPortNumber"
        }

        if ( $HostRoutePortNumber.Length -gt 0) {
            $Arguments += "HOSTROUTEPORTNUMBER=$HostRoutePortNumber"
        }

        if ( $JSMPortNumber.Length -gt 0) {
            $Arguments += "JSMPORTNUMBER=$JSMPortNumber"
        }

        if ( $JSMAdminPortNumber.Length -gt 0) {
            $Arguments += "JSMADMINPORTNUMBER=$JSMAdminPortNumber"
        }

        if ( $HTTPPortNumberHub.Length -gt 0) {
            $Arguments += "HTTPPORTNUMBERHUB=$HTTPPortNumberHub"
        }

        if ( $GitRepoUrl.Length -gt 0) {
            $Arguments += "GITREPOURL=$GitRepoUrl"
        }

        if ( $GitRepoBranch.Length -gt 0) {
            $Arguments += "GITREPOBRANCH=$GitRepoBranch"
        }

        Write-Host ("$(Log-Date) Arguments = $Arguments")

        $x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
        Remove-Item $x_err -Force -ErrorAction SilentlyContinue | Out-Default | Write-Host

        if ( $SUDB -ne '1' -and ($Cloud -ne "Docker") ) {
            Write-Host ("$(Log-Date) Waiting for Database tables to be created...")
            Start-Sleep -s 60
        }

        if ( $UPGD_bool )
        {
            Write-Host ("$(Log-Date) Upgrading LANSA")
            $Arguments += "CREATENEWUSERFORSERVICE=""Use Existing User"""
            $p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru
        }
        else
        {
            Write-Host ("$(Log-Date) Installing LANSA")
            $Arguments += "APPA=""$APPA""", "CREATENEWUSERFORSERVICE=""Create New Local User"""
            $p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru
        }

        if ( $p.ExitCode -ne 0 ) {
            $ExitCode = $p.ExitCode
            $ErrorMessage = "MSI Install returned error code $($p.ExitCode)."
            Write-Error $ErrorMessage -Category NotInstalled
            throw $ErrorMessage
        }

        if ( -not $CompanionInstall ) {
            Write-Host ("$(Log-Date) Remap licenses to new instance Guid and set permissions so that webuser may access them" )

            &"$Script:IncludeDir\activate-all-licenses.ps1"  $webuser

            Write-Host ("$(Log-Date) Allow webuser to create directory in c:\windows\temp so that LOB and BLOB processing works" )

            Set-AccessControl $webuser "C:\Windows\Temp" "Modify" "ContainerInherit, ObjectInherit" | Out-Default | Write-Host
        }

        $JSMpath = Join-Path $APPA 'Integrator\Jsmadmin\Strjsm.exe'
        if ( (test-path $JSMpath) ) {
            $JSM = @(Get-WmiObject win32_service | ?{$_.Name -like 'LANSA Integrator*'} | select Name, DisplayName, State, PathName )
            # $JSM | format-list | Out-Default | Write-Host

            $JSMServiceName = $null
            foreach ( $JSMInstance in $JSM) {
                # $JSMInstance.PathName
                if ( $JSMInstance.PathName -eq $JSMPath) {
                    Write-Host( "$(Log-Date) JSM Service details:")
                    $JSMInstance | format-list | Out-Host
                    $JSMServiceName = $JSMInstance.Name
                    Write-Host( "$(Log-Date) JSM Service name is $JSMServiceName")
                    break
                }
            }

            if ( -not [string]::IsNullOrWhiteSpace( $JSMServiceName) ) {
                # if ( $Cloud -eq "Azure" ) {
                #     Write-Host "$(Log-Date) Set JSM Service dependencies"
                #     Write-Verbose "$(Log-Date) Integrator Service on Azure requires the Azure services it tests for licensing to be dependencies" | Out-Default | Write-Host
                #     Write-Verbose "$(Log-Date) so that they are running when the license check is made by the Integrator service." | Out-Default | Write-Host
                #     cmd /c "sc.exe" "config" $JSMServiceName "depend=" "WindowsAzureGuestAgent/WindowsAzureTelemetryService" | Out-Default | Write-Host
                # }

                Write-Host ("$(Log-Date) Restart JSM Service to load the new license")
                Write-Host ( "$(Log-Date) Stopping...")
                cmd /c "sc.exe" "stop" $JSMServiceName | Out-Default | Write-Host
                Write-Host( "Pause for 30 seconds to ensure its properly stopped")
                Start-Sleep 30
                Write-Host ( "$(Log-Date) Starting...")
                cmd /c "sc.exe" "start" $JSMServiceName | Out-Default | Write-Host
            } else {
                throw "JSM service is not installed correctly in $JSMpath"
            }
        } else {
            Write-Warning( "$(Log-Date) $JSMpath is not installed") | Out-Default | Write-Host
        }

        Write-Host( "$(Log-Date) It was noticed that occasionally on Japanese systems running on Azure that the Listener was stopped. It was postulated that it may be because it starts too soon after booting. So this code changes the Listener to perform a delayed start when booting." )

        $ListenerPath = Join-Path $APPA '\connect64\lcolist.exe'
        if ( (test-path $ListenerPath) ) {
            $Listener = @(Get-WmiObject win32_service | ?{$_.Name -like 'LConnect Services*'} | select Name, DisplayName, State, PathName )
            $Listener | Out-Default

            $ListenerServiceName = $null
            foreach ( $ListenerInstance in $Listener) {
                # $ListenerInstance.PathName
                if ( $ListenerInstance.PathName -eq $ListenerPath) {
                    Write-Host( "$(Log-Date) Listener Service details:")
                    $ListenerInstance | format-list | Out-Host
                    $ListenerServiceName = $ListenerInstance.Name
                    Write-Host( "$(Log-Date) Listener Service name is $ListenerServiceName")
                    break
                }
            }

            if ( -not [string]::IsNullOrWhiteSpace( $ListenerServiceName) ) {
                # if ( $Cloud -eq "Azure" ) {
                #     Write-Host "$(Log-Date) Set Listener Service dependencies"
                #     Write-Verbose "$(Log-Date) Integrator Service on Azure requires the Azure services it tests for licensing to be dependencies" | Out-Default | Write-Host
                #     Write-Verbose "$(Log-Date) so that they are running when the license check is made by the Integrator service." | Out-Default | Write-Host
                #     cmd /c "sc.exe" "config" $ListenerServiceName "depend=" "WindowsAzureGuestAgent/WindowsAzureTelemetryService" | Out-Default | Write-Host
                # }

                Write-Host ("$(Log-Date) Configure Listener Service for Delayed Start")
                cmd /c "sc.exe" "stop" "$ListenerServiceName" | Out-Default | Write-Host
                Write-Host ( "$(Log-Date) Configuring...")
                cmd /c "sc.exe" "config" "$ListenerServiceName" "start=" "delayed-auto" | Out-Default
                Write-Host ( "$(Log-Date) Starting...")
                cmd /c "sc.exe" "start" "$ListenerServiceName" | Out-Default | Write-Host
            } else {
                throw "Listener service is not installed correctly in $ListenerPath"
            }
        } else {
            Write-Warning( "$(Log-Date) $ListenerPath is not installed") | Out-Default | Write-Host
        }

        if ( (-not $CompanionInstall) -and (-not $UPGD_bool) ) {
            Write-Host ("$(Log-Date) Switch off Sentinel ")
            New-Item -Path HKLM:\Software\LANSA\Common -Force | Out-Null
            New-ItemProperty -Path HKLM:\Software\LANSA\Common  -Name 'UseSentinelLicence' -Value 0 -PropertyType DWORD -Force | Out-Null

            [Environment]::SetEnvironmentVariable("LSFORCEHOST", "NONET", "Machine") | Out-Default | Write-Host
        }

        Write-Host ("$(Log-Date) Execute the user script if one has been passed")

        if ($userscripthook)
        {
            Write-Host ("$(Log-Date) It is executed on the first install and for upgrade, so either make it idempotent or don't pass the script name when upgrading")

            $UserScriptFile = "C:\LANSA\UserScript.ps1"
            Write-Host ("$(Log-Date) Downloading $userscripthook to $UserScriptFile")
            ( New-Object Net.WebClient ). DownloadFile($userscripthook, $UserScriptFile) | Out-Default | Write-Host

            if ( Test-Path $UserScriptFile )
            {
                Write-Host ("$(Log-Date) Executing $UserScriptFile")

                Invoke-Expression "$UserScriptFile -Server_name $server_name -dbname $dbname -dbuser $dbuser -webuser $webuser -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -userscripthook $userscripthook" | Out-Default | Write-Host
            }
            else
            {
            Write-Error ("$UserScriptFile does not exist")
            throw ("$UserScriptFile does not exist")
            }
        }
        else
        {
            Write-Verbose ("User Script not passed") | Out-Default | Write-Host
        }


        if ( -not $CompanionInstall ) {
            iis-reset | Out-Default | Write-Host
        }

        #####################################################################################
        # Test if post install x_run processing had any fatal errors
        # Performed at the end as errors may occur due to the loadbalancer probe executing
        # before LANSA has completed installing.
        # This allows it to continue.
        #####################################################################################

        if ( (Test-Path -Path $x_err) )
        {
            Write-Verbose ("$(Log-Date) Signal to Cloud log that the installation has failed") | Out-Default | Write-Host

            $ErrorMessage = "$x_err exists and indicates an installation error has occurred."
            Write-Error $ErrorMessage -Category NotInstalled
            throw $ErrorMessage
        }
    }
    Write-Host ("$(Log-Date) Installation completed successfully")
} catch {
    Write-Host ("$(Log-Date) Installation error")
    $_
    # To show inner exception...
    Write-Host "$(Log-Date) Exception caught: $($_.Exception)"

    # Show other details if they exist
    If ($_.Exception.Response) {
        $response = ($_.Exception.Response ).ToString().Trim();
        Write-Host ("$(Log-Date) Exception.Response $response")
    }
    If ($_.Exception.Response.StatusCode.value__) {
        $htmlResponseCode = ($_.Exception.Response.StatusCode.value__ ).ToString().Trim();
        Write-Host ("$(Log-Date) ResponseCode $htmlResponseCode")
    }
    If  ($_.Exception.Message) {
        $exceptionMessage = ($_.Exception.Message).ToString().Trim()
        Write-Host ("$(Log-Date) Exception.Message $exceptionMessage")
    }
    If  ($_.ErrorDetails.Message) {
        $exceptionDescription = ($_.ErrorDetails.Message).ToString().Trim()
        Write-Host ("$(Log-Date) ErrorDetails.Message $exceptionDescription")
    }

    #####################################################################################
    if ( $ExitCode -eq 0 -and $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        $ExitCode = $LASTEXITCODE
    }
    if ($ExitCode -eq 0 -or -not $ExitCode) {$ExitCode = 1}

    switch ($ExitCode){
        1619 {
            $ErrorMessage = "The MSI is already uninstalled"
        }
        1605 {
            $ErrorMessage = "The MSI is not installed"
        }
        1603 {
            $ErrorMessage = "An installer error => look at $install_log"
        }
        1602 {
            $ErrorMessage = "The same version of the MSI is already installed but its a different incompatible build of the MSI. See the powershell.log file"
        }
        1 {
            $ErrorMessage = "Command line error when executing the powershell script. See the main log file"
        }
        default {
            $ErrorMessage = "Unknown error code"
        }
    }

    Write-Host( "The MSI Install overwrites the Common Files directory registry entry.")
    Write-Host( "So ensure it is still set up correctly so that Cloud Account Id licenses will work")
    $RegKey = "HKLM:\Software\lansa\Common"
    $RegProperty = "LicenseDir"
    if ( -not (Test-RegistryValue $RegKey $RegProperty)) {
        if ( -not (Test-Path $RegKey) ) {
            Write-Host( "Creating registry entry $RegKey")
            New-Item -Path HKLM:\Software\lansa -Name Common | Out-Default | Write-Host
        } else {
            Write-Host( "$RegKey already exists")
        }

        $RegProperty = "LicenseDir"
        $LicenseDir =  "${env:ProgramFiles(x86)}\Common Files\LANSA"
        Write-Host( "Creating registry value $RegProperty")
        Set-ItemProperty -Path $RegKey -Name $RegProperty -Value $LicenseDir | Out-Default | Write-Host
    }

    Write-Host ("$(Log-Date) State Before returning: ExitCode=$($ExitCode) : $ErrorMessage")

    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    return
}
finally
{
    Write-Host ("$(Log-Date) See $install_log and other files in $ENV:TEMP for more details.")
    if ( $Cloud -eq "AWS" ) {
        Write-Host ("$(Log-Date) Also see C:\cfn\cfn-init\data\metadata.json for the CloudFormation template with all parameters expanded.")
    } else {
        if ($Cloud -eq "Azure") {
            Write-Host ("$(Log-Date) Also see C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\CustomScriptHandler.log for an overview of the result.")
            Write-Host ("$(Log-Date) and C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Status for the trace of this install.")
        }
    }

    Write-Host( "$(Log-Date) Attempt to ensure that IIS is running by starting it. (Should already be started)")
    iisreset /start | Out-Default | Write-Host

    # iisreset resets $LASTEXITCODE
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0 | Out-Default | Write-Host
