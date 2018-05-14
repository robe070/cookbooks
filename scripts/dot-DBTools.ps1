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
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

        if ( -not $dbuser ) {
            Write-Output( "Trusted Connection" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; trusted_connection = true;"
        } else {
            Write-Output( "SQL Authentication" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; User ID = $dbuser; Password = $dbpassword;"
        }
        $ConnectionString
        $ServerConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $ServerConnection.ConnectionString = $ConnectionString

        $SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerConnection)
    }
    Catch {
        $_
        Write-Output ("Database connection failed. Is SQL Server running? Are login parameters correct?")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
    }
    Catch
    {
        $_
        throw ("Error using SQL Server cmdlets")
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
    
    # Delete database in SQL Server
    Write-Output ("Deleting database")

    # This requires the Powershell SQL Server cmdlets to be imported. This should already be done
    Try {
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')

        if ( -not $dbuser ) {
            Write-Output( "Trusted Connection" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; trusted_connection = true;"
        } else {
            Write-Output( "SQL Authentication" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; User ID = $dbuser; Password = $dbpassword;"
        }
        $ConnectionString
        $ServerConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $ServerConnection.ConnectionString = $ConnectionString

        $SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerConnection)
    }
    Catch {
        $_
        Write-Output ("Database connection failed. Is SQL Server running? Are login parameters correct?")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = $sqlserver.Databases.Item($dbname)
        if ( $db ) {
            $db.drop()
            Write-Output( "Database dropped")
        } else {
            Write-Output( "Database does not exist")
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
