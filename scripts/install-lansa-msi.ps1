<#
.SYNOPSIS

Install a LANSA MSI.
Creates a SQL Server Database then installs the MSI

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules. 
E.g. The password is sufficiently complex and the userid is not duplicated in the password. 
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER"

.EXAMPLE


#>
param(
[String]$server_name='robertpc\sqlserver2012',
[String]$dbname='test1',
[String]$dbuser = 'admin',
[String]$dbpassword = 'password',
[String]$webuser = 'PCXUSER2',
[String]$webpassword = 'PCXUSER@122',
[String]$32bit = 'true',
[String]$SUDB = '1',
[String]$UPGD = 'false'
)

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

$trusted="NO"

# $DebugPreference = "Continue"

Write-Debug ("Server_name = $server_name")
Write-Debug ("dbname = $dbname")
Write-Debug ("dbuser = $dbuser")
Write-Debug ("webuser = $webuser")
Write-Debug ("32bit = $32bit")
Write-Debug ("SUDB = $SUDB")
Write-Debug ("UPGD = $UPGD")

if ( $32bit -eq 'true' -or $32bit -eq '1')
{
    $32Bit_bool = $true
}
else
{
    $32Bit_bool = $false
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

# Require MS C runtime to be installed

if ( $SUDB -eq '1' -and -not $UPGD_bool)
{
    # Create database in SQL Server
    Write-Output ("Creating database")

    # This requires the Powershell SQL Server cmdlets to be installed. This should already be done
    # choco install SQL2012.PowerShell
    Try
    {
        Add-Type -Path "C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Smo.dll"

        $SqlServer = new-Object Microsoft.SqlServer.Management.Smo.Server("$server_name")

        $SqlServer.ConnectionContext.LoginSecure = $false

        $SqlServer.ConnectionContext.Login = $dbuser

        $SqlServer.ConnectionContext.SecurePassword = convertto-securestring -string $dbpassword -AsPlainText -Force
    }
    Catch
    {
        $_
        Write-Output ("Error using SQL Server cmdlets")
        break;
    }

    $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
    Try
    {
        $db.Create()
    }
    Catch
    {
        # Its expected to fail on 2nd and subsequent EC2 instances or iterations
    }
    Write-Output ($db.CreateDate)
}

if ( -not $UPGD_bool )
{
    Start-WebAppPool -Name "DefaultAppPool"
}

# Install the application

$installer = "MyApp.msi"
$installer_file = ( Join-Path -Path "c:\lansa" -ChildPath $installer )
$install_log = ( Join-Path -Path $ENV:TEMP -ChildPath "MyApp.log" )

if ($32bit_bool)
{
    $APPA = "${ENV:ProgramFiles(x86)}\LANSA"
}
else
{
    $APPA = "${ENV:ProgramFiles}\LANSA"
}


[String[]] $Arguments = @( "/lv*x $install_log", "SHOWCODES=1", "REQUIRES_ELEVATION=1", "DBII=LANSA", "DBSV=$server_name", "DBAS=$dbname", "DBUS=$dbuser", "PSWD=$dbpassword", "TRUSTED_CONNECTION=$trusted", "SUDB=$SUDB",  "USERIDFORSERVICE=$webuser", "PASSWORDFORSERVICE=$webpassword")

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

Write-Output ( "Installation completed")
Write-Output ("See $install_log and other files in $ENV:TEMP for more details")
