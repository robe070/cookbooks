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
[String]$installMSI = 1,
[String]$updateMSI = 0,
[String]$triggerWebConfig = 1,
[String]$UninstallMSI = 0,
[String]$fixLicense = 0
)

Set-StrictMode -Version Latest

$VerbosePreference = "Continue"

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not (Test-Path variable:script:IncludeDir) )
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


# Put first output on a new line in log file
Write-Output ("`r`n")

Write-Verbose ("installMSI = $installMSI")
Write-Verbose ("updateMSI = $updateMSI")
Write-Verbose ("triggerWebConfig = $triggerWebConfig")
Write-Verbose ("UninstallMSI = $UninstallMSI")
Write-Verbose ("trace = $trace")
 
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

    Set-ItemProperty -Path "HKLM:\Software\lansa" -Name "Installing" -Value 1

    Write-Output ("$(Log-Date) Test if this is the first install")
    $installer = "MyApp.msi"
    $installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
    if (-not (Test-Path $installer_file) ) {
        $installMSI = "1"
        $triggerWebConfig = "1"
    }

    Write-Output ("$(Log-Date) Setup tracing for both this process and its children and any processes started after the installation has completed.")

    if ($trace -eq "Y") {
        Write-Output ("$(Log-Date) Set tracing on" )
        [Environment]::SetEnvironmentVariable("X_RUN", $traceSettings, "Machine")
        $env:X_RUN = $traceSettings
    } else {
        Write-Output ("$(Log-Date) Set tracing off" )
        [Environment]::SetEnvironmentVariable("X_RUN", $null, "Machine")
        $env:X_RUN = ''
    }

    Write-Output ("$(Log-Date) Restart web server if not already planned to be done by a later script")

    if ($trace -eq "Y" -and $installMSI -eq "0" -and $updateMSI -eq "0" -and $uninstallMSI -eq "0" -and $triggerWebConfig -eq "0" ) {
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
    }
        
    if ( $uninstallMSI -eq "1" ) {
        msiexec /quiet /x $installer_file
    }

    if ( $installMSI -eq "1" ) {
        .$script:IncludeDir\install-lansa-msi.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD "0" -MSIuri $MSIuri -trace $trace -tracesettings $traceSettings
    } elseif ( $updateMSI -eq "1" ) {
        .$script:IncludeDir\install-lansa-msi.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD "1" -MSIuri $MSIuri -trace $trace -tracesettings $traceSettings
    }

    if ( $triggerWebConfig -eq "1" ) {
        .$script:IncludeDir\webconfig.ps1 -server_name $server_name -DBUT $DBUT -dbname $dbname -dbuser $dbuser -dbpassword $dbpassword -webuser $webuser -webpassword $webpassword -f32bit $f32bit -SUDB $SUDB -UPGD $UPGD -maxconnections $maxconnections 
    }

    if ( $fixLicense -eq "1" ) {
	    Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" $webuser
	    Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" $webuser
	    Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser
    }
}
catch
{
    Write-Error ("azure-custom-script failed")
    cmd /c exit 3
}
finally
{
    Set-ItemProperty -Path "HKLM:\Software\lansa" -Name "Installing" -Value 0
}

