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
[String]$userscripthook
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

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

Write-Debug ("Server_name = $server_name")
Write-Debug ("dbname = $dbname")
Write-Debug ("dbuser = $dbuser")
Write-Debug ("webuser = $webuser")
Write-Debug ("32bit = $f32bit")
Write-Debug ("SUDB = $SUDB")
Write-Debug ("UPGD = $UPGD")

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

    Write-Debug ("UPGD_bool = $UPGD_bool" )

    $temp_out = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install.log )
    $temp_err = ( Join-Path -Path $ENV:TEMP -ChildPath temp_install_err.log )

    $x_err = (Join-Path -Path $ENV:TEMP -ChildPath 'x_err.log')
    Remove-Item $x_err -Force -ErrorAction SilentlyContinue

    $installer = "MyApp.msi"
    $installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
    $install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "MyApp.log" )

    # On initial install disable TCP Offloading

    if ( -not $UPGD_bool )
    {
        Disable-TcpOffloading
    }

    ######################################
    # Require MS C runtime to be installed
    ######################################

    if ( $SUDB -eq '1' -and -not $UPGD_bool)
    {
        Write-Output ("$(Log-Date) Ensure SQL Server Powershell module is loaded.")

        Write-Verbose ("Loading this module changes the current directory to 'SQLSERVER:\'. It will need to be changed back later")

        Import-Module “sqlps” -DisableNameChecking

        if ( $SUDB -eq '1' -and -not $UPGD_bool)
        {
            Create-SqlServerDatabase $server_name $dbname $dbuser $dbpassword
        }

        Write-Verbose ("Change current directory from 'SQLSERVER:\' back to the file system so that file pathing works properly")
        cd "c:"
    }

    if ( -not $UPGD_bool )
    {
        Start-WebAppPool -Name "DefaultAppPool"
    }

    Write-Output ("Installing the application")

    if ($f32bit_bool)
    {
        $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
    }
    else
    {
        $APPA = "${ENV:ProgramFiles}\LANSA"
    }


    [String[]] $Arguments = @( "/quiet /lv*x $install_log", "SHOWCODES=1", "USEEXISTINGWEBSITE=1", "REQUIRES_ELEVATION=1", "DBII=LANSA", "DBSV=$server_name", "DBAS=$dbname", "DBUS=$dbuser", "PSWD=$dbpassword", "TRUSTED_CONNECTION=$trusted", "SUDB=$SUDB",  "USERIDFORSERVICE=$webuser", "PASSWORDFORSERVICE=$webpassword")

    Write-Output ("Arguments = $Arguments")

    if ( $UPGD_bool )
    {
        Write-Output ("Upgrading LANSA")
        $Arguments += "CREATENEWUSERFORSERVICE=""Use Existing User"""
        Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait
    }
    else
    {
        Write-Output ("Installing LANSA")
        $Arguments += "APPA=""$APPA""", "CREATENEWUSERFORSERVICE=""Create New Local User"""
        Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait
    }

    #####################################################################################
    # Test if post install x_run processing had any fatal errors
    #####################################################################################

    if ( (Test-Path -Path $x_err) )
    {
        Write-Verbose ("Signal to Cloud Formation that the installation has failed")

        $ErrorMessage = "$x_err exists and indicates an installation error has occurred."
        Write-Error $ErrorMessage -Category NotInstalled
        throw $ErrorMessage
    }

	Write-output ("Remap licenses to new instance Guid and set permissions so that webuser may access them" )

	Map-LicenseToUser "LANSA Scalable License" "ScalableLicensePrivateKey" $webuser
	Map-LicenseToUser "LANSA Integrator License" "IntegratorLicensePrivateKey" $webuser
	Map-LicenseToUser "LANSA Development License" "DevelopmentLicensePrivateKey" $webuser

	Write-output ("Allow webuser to create directory in c:\windows\temp so that LOB and BLOB processing works" )
    
    Set-AccessControl $webuser "C:\Windows\Temp" "Modify" "ContainerInherit, ObjectInherit"

    Write-Output ("Execute the user script if one has been passed")

    if ($userscripthook)
    {
        Write-Output ("It is executed on the first install and for upgrade, so either make it idempotent or don't pass the script name when upgrading")

        $UserScriptFile = "C:\LANSA\UserScript.ps1"
        Write-Output ("Downloading $userscripthook to $UserScriptFile")
        ( New-Object Net.WebClient ). DownloadFile($userscripthook, $UserScriptFile)

        if ( Test-Path $UserScriptFile )
        {
            Write-Output ("Executing $UserScriptFile")

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

    Write-Output ("Installation completed successfully")
}
catch
{
	$_
    Write-Error ("Installation error")
    throw
}
finally
{
    Write-Output ("See $install_log and other files in $ENV:TEMP for more details.")
    Write-Output ("Also see C:\cfn\cfn-init\data\metadata.json for the CloudFormation template with all parameters expanded.")
}

# Successful completion so set Last Exit Code to 0
cmd /c exit 0
