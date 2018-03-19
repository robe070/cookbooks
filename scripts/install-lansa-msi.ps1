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
[String]$ApplName = "MyApp",
[String]$CompanionInstallPath = "",
[String]$HTTPPortNumber = "",
[String]$HostRoutePortNumber = "",
[String]$JSMPortNumber = "",
[String]$JSMAdminPortNumber = "",
[String]$HTTPPortNumberHub = "",
[String]$GitRepoUrl = ""
)

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


# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

$trusted="NO"

$DebugPreference = "SilentlyContinue"
$VerbosePreference = "Continue"

Write-Verbose ("Server_name = $server_name")
Write-Verbose ("dbname = $dbname")
Write-Verbose ("dbuser = $dbuser")
Write-Verbose ("webuser = $webuser")
Write-Verbose ("32bit = $f32bit")
Write-Verbose ("SUDB = $SUDB")
Write-Verbose ("UPGD = $UPGD")
Write-Verbose ("DBUT = $DBUT")
Write-Verbose ("Password = $dbpassword")
Write-Verbose ("ApplName = $ApplName")
Write-Verbose ("CompanionInstallPath = $CompanionInstallPath")
Write-Verbose ("Wait Handle = $Wait")


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

    Write-Debug ("$(Log-Date) UPGD_bool = $UPGD_bool" )

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

    $installer = "$($ApplName).msi"

    $installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
    $install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "$($ApplName).log" )

    # Docker passes in a local path to the MSI which is mapped to a host volume
    # Just copy it to the standard name - its used to determine if an upgrade or not.
    if ( $Cloud -eq "Docker") {
        Copy-Item -Path $MSIUri -Destination $installer_file -Force
    }

    if ( $MSIuri.Length -gt 0 -and ($Cloud -eq "Azure" -or ($Cloud -eq "AWS")) ) {
        Write-Verbose ("$(Log-Date) Downloading $MSIuri to $installer_file")
        (New-Object System.Net.WebClient).DownloadFile($MSIuri, $installer_file)
    }

    if ( (-not $CompanionInstall) -and ($Cloud -eq "Azure"  -or $Cloud -eq "Docker") ) {
        # ODBC Driver originally installed due to SQLAZURE driver needing to be updated because of C00001A5 exceptions caused by SqlDriverConnect
        Write-Output ("$(Log-Date) Checking ODBC driver for Database Type $DBUT")

        switch -regex ($DBUT) {
            "SQLAZURE|MSSQL" {
                $DRIVERURL = "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/msodbcsqlx64.msi"
                [String[]] $Arguments = @( "/quiet", "/lv*x $( Join-Path -Path $ENV:TEMP -ChildPath "odbc.log" )", "IACCEPTMSODBCSQLLICENSETERMS=YES")
            }
            "MYSQL" {
                $DRIVERURL32 = "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/mysql-connector-odbc-win32.msi"
                $DRIVERURL = "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/mysql-connector-odbc-winx64.msi"
                [String[]] $Arguments = @( "/quiet")
            }
            default {
                $ExitCode = 2
                $ErrorMessage = "Database Type $DBUT not supported. Requires an ODBC driver to be installed by this script"
                Write-Error $ErrorMessage -Category NotInstalled
                throw $ErrorMessage
            }
        }
        $odbc_installer_file = ( Join-Path -Path $ENV:TEMP -ChildPath "odbc_driver.msi" )
        $odbc_installer_file32 = ( Join-Path -Path $ENV:TEMP -ChildPath "odbc_driver32.msi" )
        Write-Verbose ("$(Log-Date) Downloading $DRIVERURL to $odbc_installer_file")
        (New-Object System.Net.WebClient).DownloadFile($DRIVERURL, $odbc_installer_file)

        $p = Start-Process -FilePath $odbc_installer_file -ArgumentList $Arguments -Wait -PassThru
        if ( $p.ExitCode -ne 0 ) {
            $ExitCode = $p.ExitCode
            $ErrorMessage = "ODBC Install returned error code $($p.ExitCode)."
            Write-Error $ErrorMessage -Category NotInstalled
            throw $ErrorMessage
        }

        if ( (test-path variable:\DRIVERURL32) ) {
            Write-Verbose ("$(Log-Date) Downloading $DRIVERURL32 to $odbc_installer_file32")
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

    # On initial install

    if ( (-not $CompanionInstall) -and (-not $UPGD_bool) )
    {
        Write-Output ("$(Log-Date) Disable TCP Offloading" )
        Disable-TcpOffloading

        # When installing through cloudformation the current user is systemprofile.
        # When GitDeployHub receives a webhook it may be running as administrator

        Write-Output ("$(Log-Date) Add github.com to known_hosts for current user and for Administrator" )
        $KnownHostsDir = "$ENV:USERPROFILE\.ssh"
        if ( -not (test-path $KnownHostsDir)) {
            mkdir $KnownHostsDir          
        }
        Get-Content "$script:IncludeDir\github.txt" | out-file  "$KnownHostsDir\known_hosts" -Append -encoding utf8

        # If there is an adminstrator user, create the known hosts there too.
        $KnownHostsDir = "c:\users\administrator"
        if ( (test-path $KnownHostsDir)) {
            $KnownHostsDir = "$KnownHostsDir\.ssh"
            if ( -not (test-path $KnownHostsDir)) {
                mkdir $KnownHostsDir          
            }
            Get-Content "$script:IncludeDir\github.txt" | out-file  "$KnownHostsDir\known_hosts" -Append -encoding utf8
        }

        Write-Output ("$(Log-Date) Open Windows Firewall for HTTP ports...")
        Write-Output ("$(Log-Date) Note that these port numbers are what has been specified on the command line. If they are in use the LANSA Install will find the next available port and use that. So, strictly, should really pick up the port number after the lansa install has been run from the web site itself. For now, we know the environment as its a cloud image that we build.")
        if ( $HTTPPortNumber.Length -gt 0 -and $HTTPPortNumber -ne "80") {
            New-NetFirewallRule -DisplayName 'LANSA HTTP Inbound'-Direction Inbound -Action Allow -Protocol TCP -LocalPort @("$HTTPPortNumber")
        }
        if ( $HTTPPortNumberHub.Length -gt 0) {
            New-NetFirewallRule -DisplayName 'GitDeployHub Inbound'-Direction Inbound -Action Allow -Protocol TCP -LocalPort @("$HTTPPortNumberHub")
        }
    }

    #########################################################################################################
    # Database setup
    # Microsoft introduced a defect on 27/10/2016 whereby this code abended when used with Azure SQL Database
    # The template creates the database so it was conditioned out.
    #########################################################################################################

    if ( ($SUDB -eq '1') -and (-not $UPGD_bool) )
    {
        switch ($DBUT) {
            "MSSQLS" {
                Write-Output ("$(Log-Date) Database Setup work...")

                Write-Output ("$(Log-Date) Ensure SQL Server Powershell module is loaded.")

                Write-Verbose ("$(Log-Date) Loading this module changes the current directory to 'SQLSERVER:\'. It will need to be changed back later")

                Import-Module “sqlps” -DisableNameChecking

                if ( $SUDB -eq '1' -and -not $UPGD_bool)
                {
                    Create-SqlServerDatabase $server_name $dbname $dbuser $dbpassword
                }

                Write-Verbose ("$(Log-Date) Change current directory from 'SQLSERVER:\' back to the file system so that file pathing works properly")
                cd "c:"
            }
            default {
                Write-Output ("$(Log-Date) Database presumed to exist")
            }
        }
    }

    if ( -not $CompanionInstall ) {
        if ( -not $UPGD_bool )
        {
            Start-WebAppPool -Name "DefaultAppPool"
        }

        Write-Output ("$(Log-Date) Setup tracing for both this process and its children and any processes started after the installation has completed.")

        if ($trace -eq "Y") {
            [Environment]::SetEnvironmentVariable("X_RUN", $traceSettings, "Machine")
            $env:X_RUN = $traceSettings
        } else {
            [Environment]::SetEnvironmentVariable("X_RUN", $null, "Machine")
            $env:X_RUN = ''
        }
    }
    
    Write-Output ("$(Log-Date) Installing the application")

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\$($ApplName)"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\$($ApplName)"
    }


    [String[]] $Arguments = @( "/quiet /lv*x $install_log", "SHOWCODES=1", "USEEXISTINGWEBSITE=1", "REQUIRES_ELEVATION=1", "DBUT=$DBUT", "DBII=$($ApplName)", "DBSV=$server_name", "DBAS=$dbname", "DBUS=$dbuser", "PSWD=$dbpassword", "TRUSTED_CONNECTION=$trusted", "SUDB=$SUDB",  "USERIDFORSERVICE=$webuser", "PASSWORDFORSERVICE=$webpassword")

    # Arguments to pass only if they have a value
    if ( $CompanionInstallPath.Length -gt 0) {
        $Arguments += "COMPANIONINSTALLPATH=`"$CompanionInstallPath`""
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

    Write-Output ("$(Log-Date) Arguments = $Arguments")

    $x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue
    
    if ( $UPGD_bool )
    {
        Write-Output ("$(Log-Date) Upgrading LANSA")
        $Arguments += "CREATENEWUSERFORSERVICE=""Use Existing User"""
        $p = Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait -PassThru
    }
    else
    {
        Write-Output ("$(Log-Date) Installing LANSA")
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
        Write-output ("$(Log-Date) Remap licenses to new instance Guid and set permissions so that webuser may access them" )

        Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" $webuser
        Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" $webuser
        Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser

        Write-output ("$(Log-Date) Allow webuser to create directory in c:\windows\temp so that LOB and BLOB processing works" )
        
        Set-AccessControl $webuser "C:\Windows\Temp" "Modify" "ContainerInherit, ObjectInherit"
    }

    if ( (test-path "$APPA\Integrator\Jsminstance\System\Jsmsupp.exe") ) {
        $JSMServiceName = '"LANSA Integrator JSM Administrator Service 1 - 14.1 (LIN14100_EPC141005)"'
        if ( $Cloud -eq "Azure" ) {
            Write-Output "$(Log-Date) Set JSM Service dependencies"
            Write-Verbose "$(Log-Date) Integrator Service on Azure requires the Azure services it tests for licensing to be dependencies"
            Write-Verbose "$(Log-Date) so that they are running when the license check is made by the Integrator service."
            cmd /c "sc.exe" "config" $JSMServiceName "depend=" "WindowsAzureGuestAgent/WindowsAzureTelemetryService" | Write-Output
        }

        Write-output ("$(Log-Date) Restart JSM Service to load the new license")
        cmd /c "sc.exe" "stop" $JSMServiceName
        cmd /c "sc.exe" "start" $JSMServiceName
    }

    Write-Output ("$(Log-Date) Execute the user script if one has been passed")

    if ($userscripthook)
    {
        Write-Output ("$(Log-Date) It is executed on the first install and for upgrade, so either make it idempotent or don't pass the script name when upgrading")

        $UserScriptFile = "C:\LANSA\UserScript.ps1"
        Write-Output ("$(Log-Date) Downloading $userscripthook to $UserScriptFile")
        ( New-Object Net.WebClient ). DownloadFile($userscripthook, $UserScriptFile)

        if ( Test-Path $UserScriptFile )
        {
            Write-Output ("$(Log-Date) Executing $UserScriptFile")

            Invoke-Expression "$UserScriptFile -Server_name $server_name -dbname $dbname -dbuser $dbuser -webuser $webuser -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -userscripthook $userscripthook"
        }
        else
        {
           Write-Error ("$UserScriptFile does not exist")
           throw ("$UserScriptFile does not exist")
        }
    }
    else
    {
        Write-Verbose ("User Script not passed")
    }

    if ( -not $CompanionInstall ) {
        iisreset
    }

    #####################################################################################
    # Test if post install x_run processing had any fatal errors
    # Performed at the end as errors may occur due to the loadbalancer probe executing
    # before LANSA has completed installing.
    # This allows it to continue.
    #####################################################################################

    if ( (Test-Path -Path $x_err) )
    {
        Write-Verbose ("$(Log-Date) Signal to Cloud log that the installation has failed")

        $ErrorMessage = "$x_err exists and indicates an installation error has occurred."
        Write-Error $ErrorMessage -Category NotInstalled
        throw $ErrorMessage
    }

    Write-Output ("$(Log-Date) Installation completed successfully")
}
catch
{
	$_
    Write-Output ("$(Log-Date) Installation error")
    if ( $ExitCode -eq 0 -and $LASTEXITCODE -ne 0) {
        $ExitCode = $LASTEXITCODE
    }
    if ($ExitCode -eq 0 ) {$ExitCode = 1}
            
    cmd /c exit $ExitCode    #Set $LASTEXITCODE
    return
}
finally
{
    Write-Output ("$(Log-Date) See $install_log and other files in $ENV:TEMP for more details.")
    if ( $Cloud -eq "AWS" ) {
        Write-Output ("$(Log-Date) Also see C:\cfn\cfn-init\data\metadata.json for the CloudFormation template with all parameters expanded.")
    } else {
        if ($Cloud -eq "Azure") {
            Write-Output ("$(Log-Date) Also see C:\WindowsAzure\Logs\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\CustomScriptHandler.log for an overview of the result.")
            Write-Output ("$(Log-Date) Note that an exit code of 1603 is an installer error so look at $install_log")
            Write-Output ("$(Log-Date) and C:\Packages\Plugins\Microsoft.Compute.CustomScriptExtension\1.8\Status for the trace of this install.")
        }
    }
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
