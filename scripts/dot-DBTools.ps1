<#
.SYNOPSIS

Database tools

.EXAMPLE

#>

function Disable-TcpOffloading
{
    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud

    ##########################################################################
    # Disable TCP Offloading
    # Solve SQL Server "The semaphore timeout period has expired" issue
    # Also see: http://www.evernote.com/l/AA2n3LnZl9BGA5wIz12ctU6aqwmvpYETQpI/
    # http://www.evernote.com/l/AA2JZF2lGelC8oTEKDEECWA8uNt-SbtzwuQ/
    # http://www.evernote.com/l/AA3NUlB9xtdN4qciBFoXwX_8NuWcPM0nlqY/
    ##########################################################################
    # English  'Ethernet 2'
    # Japanese 'イーサネット'
    # French   'Ethernet 2'
    get-culture
    $IsoLang = (Get-Culture).ThreeLetterISOLanguageName
    $IsoLang

    if ( [System.Environment]::OSVersion.Version.Major -le 6) {
        $EngNicName = 'Ethernet'
        $JpnNicName = 'イーサネット'
    } else {
        $EngNicName = 'Ethernet 2'
        $JpnNicName = 'イーサネット'
    }        

    switch ( $IsoLang ) {
        'jpn' {$NICName = $JpnNicName }
        default {$NICName = $EngNicName }
    }

    Write-Output ("Disable TCP Offloading on NIC $NICName")

    # Don't need to see NetAdapter verbose messages. First call outputs 50 lines of text
    $CurrentVerbosePreference = $VerbosePreference 
    $VerbosePreference = "SilentlyContinue"
    # Display valid values
    Get-NetAdapterAdvancedProperty $NICName
    $VerbosePreference = $CurrentVerbosePreference

    # Display existing settings:
    Get-NetAdapterAdvancedProperty $NICName | ft DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue
    # Set all the settings required to switch off TCP IPv4 offloading to fix SQL Server connection dropouts in high connection, high transaction environment:
    
    Write-Verbose ("Note that RDP connection to instance will drop out momentarily")

    Set-NetAdapterAdvancedProperty $NICName -DisplayName "IPv4 Checksum Offload" -DisplayValue "Disabled" -NoRestart
    Set-NetAdapterAdvancedProperty $NICName -DisplayName "TCP Checksum Offload (IPv4)" -DisplayValue "Disabled" -NoRestart

    if ( $Cloud -eq "AWS" ) {
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Receive Offload (IPv4)" -DisplayValue "Disabled"  -NoRestart
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled"
    } elseif ( $Cloud -eq "Azure" ) {
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Send Offload Version 2 (IPv4)" -DisplayValue "Disabled"
    }
    
    # Check its worked
    Get-NetAdapterAdvancedProperty $NICName | ft DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue 
    
    Write-Output ("TCP Offloading disabled")
}

function Create-SqlServerDatabase {
Param (
    [Parameter(Mandatory=$true)]
    [string]
    $server_name,

    [Parameter(Mandatory=$true)]
    [String]
    $dbname,

    [Parameter(Mandatory=$false)]
    [String]
    $dbuser,

    [Parameter(Mandatory=$false)]
    [String]
    $dbpassword
)

    # Create database in SQL Server
    Write-Output ("Creating database")

    # This requires the Powershell SQL Server cmdlets to be imported. This should already be done
    Try {
        # this should be unnecessary, hence commented out
        # Add-Type -Path "C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Smo.dll"

        $SqlServer = new-Object Microsoft.SqlServer.Management.Smo.Server("$Server_name")

        if ( -not $dbuser ) {
            $SqlServer.ConnectionContext.LoginSecure = $true
        } else {
            $SqlServer.ConnectionContext.LoginSecure = $false

            $SqlServer.ConnectionContext.Login = $dbuser

            $SqlServer.ConnectionContext.SecurePassword = convertto-securestring -string $dbpassword -AsPlainText -Force
        }
    }
    Catch {
        $_
        Write-Output ("Error using SQL Server cmdlets")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
    }
    Catch
    {
        $_
        Write-Output ("Database connection failed. Is SQL Server running?")
    }

    Try {
        $db.Create()
        Write-Output ($db.CreateDate)
    }
    Catch {
        $_
        Write-Output ("Database creation failed. Its expected to fail on 2nd and subsequent EC2 instances or iterations")
    }
}

function Drop-SqlServerDatabase {
    Param (
        [Parameter(Mandatory=$true)]
        [string]
        $server_name,
    
        [Parameter(Mandatory=$true)]
        [String]
        $dbname,
    
        [Parameter(Mandatory=$false)]
        [String]
        $dbuser,
    
        [Parameter(Mandatory=$false)]
        [String]
        $dbpassword
    )
    
    Write-Verbose ("Server_name = $server_name")
    Write-Verbose ("dbname = $dbname")
    Write-Verbose ("dbuser = $dbuser")

    # Delete database in SQL Server
    Write-Output ("Deleting database")

    # This requires the Powershell SQL Server cmdlets to be imported. This should already be done
    Try {
        $SqlServer = new-Object Microsoft.SqlServer.Management.Smo.Server("$Server_name")

        if ( -not $dbuser ) {
            $SqlServer.ConnectionContext.LoginSecure = $true
        } else {
            $SqlServer.ConnectionContext.LoginSecure = $false

            $SqlServer.ConnectionContext.Login = $dbuser

            $SqlServer.ConnectionContext.SecurePassword = convertto-securestring -string $dbpassword -AsPlainText -Force
        }
    }
    Catch {
        $_
        Write-RedOutput ("Database connection failed. Is SQL Server running? Are login parameters correct?")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
        if ( $db ) {
            Write-Output( "Drop any connections to database $dbname")
            Write-Output( "Current connections to $dbname = $($sqlserver.GetActiveDBConnectionCount($dbname))" )
            $sqlserver.KillAllProcesses($dbname)
            Write-Output( "Final connections to $dbname = $($sqlserver.GetActiveDBConnectionCount($dbname))" )
            
            Write-Output( "Dropping database $dbname")
            $db.drop()
            Write-Output( "Database dropped")
        } else {
            Write-RedOutput( "Database does not exist or database connection failed")
        }
    }
    Catch
    {
        $_
        throw ("Database drop failed.")
    }
}
    
##################################################################  
# Function to Enable or Disable a SQL Server Network Protocol 
################################################################## 
function Change-SQLProtocolStatus($server,$instance,$protocol,$enable){ 
 
    $smo = 'Microsoft.SqlServer.Management.Smo.' 
     
    $wmi = new-object ($smo + 'Wmi.ManagedComputer') 
 
    $singleWmi = $wmi | where {$_.Name -eq $server}   
 
    $uri = "ManagedComputer[@Name='$server']/ServerInstance[@Name='$instance']/ServerProtocol[@Name='$protocol']" 
     
    $protocol = $singleWmi.GetSmoObject($uri) 
     
    if ( $protocol.IsEnabled -ne $enable )
    {
        $protocol.IsEnabled = $enable 
     
        $protocol.Alter() 
     
        $protocol 

        return $true
    }
    return $false
} 
