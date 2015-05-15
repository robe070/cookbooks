<#
.SYNOPSIS

Install a LANSA MSI.
Creates a SQL Server Database then installs the MSI

Requires the environment that a LANSA Cake provides, particularly an AMI license.

# N.B. It is vital that the user id and password supplied pass the password rules. 
E.g. The password is sufficiently complex and the userid is not duplicated in the password. 
i.e. UID=PCXUSER and PWD=PCXUSER@#$%^&* is invalid as the password starts with the entire user id "PCXUSER".

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
[String]$wait,
[String]$userscripthook
)

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

# Check registry for restarting flags
function CheckRestart([REF]$retval)
{
	$cn = $ENV:COMPUTERNAME
    [bool]$PendingFile = $false
    [bool]$AutoUpdate = $false

	#Determine PendingFileRenameOperations exists or not  
	$PendFileKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\" 
	Invoke-Command -ComputerName $cn -ErrorAction SilentlyContinue -ScriptBlock{ 
	Get-ItemProperty -Path $using:PendFileKeyPath -name PendingFileRenameOperations} |` 
	Foreach{If($_.PendingFileRenameOperations){$PendingFile = $true}Else{$PendingFile = $false}} 
  
	#Determine RebootRequired subkey exists or not 
	$AutoUpdateKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" 
	Invoke-Command -ComputerName $cn -ErrorAction SilentlyContinue -ScriptBlock {Test-Path -Path "$using:AutoUpdateKeyPath\RebootRequired"} |` 
	Foreach{If($_ -eq $true){$AutoUpdate = $true}Else{$AutoUpdate = $false}} 

	$retval.Value = ($AutoUpdate -or $PendingFile)
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

	# Ensure a reboot is not pending as MSI install will fail if thats the case.

	# Check for restart in case reboot not detected or a prior need for reboot has failed
	# e.g. due to logged on users.
	[bool]$restart = $false
	CheckRestart( [REF]$restart)
	if ( $restart )
	{
		Logoff-Allusers

		Write-Output "Restart Required - Restarting..."
		Restart-Computer -Force
	}

    ##########################################################################
    # Disable TCP Offloading
    # Solve SQL Server "The semaphore timeout period has expired" issue
    # Also see: http://www.evernote.com/l/AA2n3LnZl9BGA5wIz12ctU6aqwmvpYETQpI/
    # http://www.evernote.com/l/AA2JZF2lGelC8oTEKDEECWA8uNt-SbtzwuQ/
    # http://www.evernote.com/l/AA3NUlB9xtdN4qciBFoXwX_8NuWcPM0nlqY/
    ##########################################################################
    if ( -not $UPGD_bool )
    {
        $NICName = 'Ethernet'
        Write-Output ("Disable TCP Offloading on NIC $NICName")

        # Don't need to see NetAdapter verbose messages. First call outputs 50 lines of text
        $VerbosePreference = "SilentlyContinue"
        # Display valid values
        Get-NetAdapterAdvancedProperty $NICName
        $VerbosePreference = "Continue"

        # Display existing settings:
        Get-NetAdapterAdvancedProperty $NICName | ft DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue
        # Set all the settings required to switch of TCP IPv4 offloading to fix SQL Server connection dropouts in high connection, high transaction environment:
    
        Write-Verbose ("Note that RDP connection to instance will drop out momentarily")

        Set-NetAdapterAdvancedProperty $NICName -DisplayName "IPv4 Checksum Offload" -DisplayValue "Disabled" -NoRestart
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled" -NoRestart
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "TCP Checksum Offload (IPv4)" -DisplayValue "Disabled" -NoRestart
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Receive Offload (IPv4)" -DisplayValue "Disabled"

        # Check its worked
        Get-NetAdapterAdvancedProperty $NICName | ft DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue 
    
        Write-Output ("TCP Offloading disabled")
    }

    ######################################
    # Require MS C runtime to be installed
    ######################################

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
            throw ("Error using SQL Server cmdlets")
        }

        $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
        Try
        {
            $db.Create()
        }
        Catch
        {
            $_
            Write-Output ("Database creation failed. Its expected to fail on 2nd and subsequent EC2 instances or iterations")
        }
        Write-Output ($db.CreateDate)
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

    #####################################################################################
    # Create new private key filename for new machine GUID
    # New key is just a copy of the old one with a change of name to replace the old Machine GUID with the new Machine GUID
    # Value for the old private key is stored in the registry key HKLM:\Software\LANSA\ScalableLicensePrivateKey
    # Value for the old Machine GUID is stored in the registry key HKLM:\Software\LANSA\PriorMachineGuid
    # Format of private key file name is <Unique for certificate no matter where it is imported to>_<Machine GUID>
    #####################################################################################
    $getCert = Get-ChildItem  -path "Cert:\LocalMachine\My" -DNSName "LANSA Scalable License"

    $Thumbprint = $getCert.Thumbprint

    $keyName=(((Get-ChildItem Cert:\LocalMachine\My | Where-Object {$_.Thumbprint -like $Thumbprint}).PrivateKey).CspKeyContainerInfo).UniqueKeyContainerName

    if ( -not $keyname )
    {
        Write-Verbose "No key"

        $ScalableLicensePrivateKey = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name ScalableLicensePrivateKey
        $PriorMachineGuid          = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name PriorMachineGuid
        $MachineGuid               = Get-ItemProperty -Path HKLM:\SOFTWARE\Microsoft\Cryptography  -Name MachineGuid

        if ( -not $ScalableLicensePrivateKey -or -not $PriorMachineGuid -or -not $MachineGuid)
        {
            Write-Error ("One of the following registry keys is invalid: HKLM:\Software\LANSA\ScalableLicensePrivateKey, HKLM:\Software\LANSA\PriorMachineGuid, HKLM:\SOFTWARE\Microsoft\Cryptography\MachineGuid")
            throw ("One of the following registry keys is invalid: HKLM:\Software\LANSA\ScalableLicensePrivateKey, HKLM:\Software\LANSA\PriorMachineGuid, HKLM:\SOFTWARE\Microsoft\Cryptography\MachineGuid")
        }

        Write-Verbose ("Replace Old Machine Guid with new Machine Guid")

        if ( ($ScalableLicensePrivateKey.ScalableLicensePrivateKey -match $PriorMachineGuid.PriorMachineGuid) -eq $true )
        {
            Write-Verbose "Guid found in Private Key"
            $NewScalableLicensePrivateKey = $ScalableLicensePrivateKey.ScalableLicensePrivateKey -replace 
                                                $($PriorMachineGuid.PriorMachineGuid + "$"), $MachineGuid.MachineGuid
            if ($ScalableLicensePrivateKey.ScalableLicensePrivateKey -eq $NewScalableLicensePrivateKey)
            {
                Write-Error ("Prior Machine GUID {0} not found at end of Scalable License Private Key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.ScalableLicensePrivateKey)
                throw ("Prior Machine GUID {0} not found at end of Scalable License Private Key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.ScalableLicensePrivateKey)
            }

            Write-Verbose ("New private key is {0}" -f $NewScalableLicensePrivateKey)
        }
        else
        {
            Write-Error ( "PriorMachine GUID {0} is not in current LANSA Scalable License Private key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.ScalableLicensePrivateKey)
            throw ( "PriorMachine GUID {0} is not in current LANSA Scalable License Private key {1}" -f $PriorMachineGuid.PriorMachineGuid, $ScalableLicensePrivateKey.ScalableLicensePrivateKey)
        }

        Write-Verbose ("Copy old key to new key")

        $keyPath = "C:\ProgramData\Microsoft\Crypto\RSA\MachineKeys\"
        $fullPath=$keyPath+$keyName
        Copy-Item $($KeyPath + $ScalableLicensePrivateKey.ScalableLicensePrivateKey) $($KeyPath + $NewScalableLicensePrivateKey)

        Write-Verbose ("Set ACLs on new key so that $webuser may access it")

        $pkFile = $($KeyPath + $NewScalableLicensePrivateKey)
        $acl=Get-Acl -Path $pkFile
        $permission= $webuser,"Read","Allow"
        $accessRule=new-object System.Security.AccessControl.FileSystemAccessRule $permission
        $acl.AddAccessRule($accessRule)
        Set-Acl $pkFile $acl
    }
    else
    {
        Write-Verbose ("Private key $keyname already exists")
    }

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
    exit 0
}
catch
{
    Write-Error ("Installation error")
    exit 2
}
finally
{
    Write-Output ("See $install_log and other files in $ENV:TEMP for more details.")
    Write-Output ("Also see C:\cfn\cfn-init\data\metadata.json for the CloudFormation template with all parameters expanded.")
}
