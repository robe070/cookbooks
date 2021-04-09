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
    get-culture | Write-Host
    $IsoLang = (Get-Culture).ThreeLetterISOLanguageName
    $IsoLang | Write-Host

    # Don't need to see NetAdapter verbose messages. First call outputs 50 lines of text
    $CurrentVerbosePreference = $VerbosePreference
    $VerbosePreference = "SilentlyContinue"

    $NicSettings = @(Get-NetAdapterAdvancedProperty)
    if ( -not $NicSettings ) {
        throw "No network adapters reported"
    }

    $NicName = $NicSettings[0].Name

    Write-Host ("Disable TCP Offloading on NIC $NICName")
    [Console]::Out.Flush()

    # Display valid values
    Get-NetAdapterAdvancedProperty $NICName | Out-Default | Write-Host
    $VerbosePreference = $CurrentVerbosePreference

    # Display existing settings:
    Get-NetAdapterAdvancedProperty $NICName | ft DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue | Out-Default | Write-Host
    # Set all the settings required to switch off TCP IPv4 offloading to fix SQL Server connection dropouts in high connection, high transaction environment:

    Write-Verbose ("Note that RDP connection to instance will drop out momentarily")
    [Console]::Out.Flush()

    Set-NetAdapterAdvancedProperty $NICName -DisplayName "IPv4 Checksum Offload" -DisplayValue "Disabled" -NoRestart | Out-Default | Write-Host
    Set-NetAdapterAdvancedProperty $NICName -DisplayName "TCP Checksum Offload (IPv4)" -DisplayValue "Disabled" -NoRestart | Out-Default | Write-Host
    [Console]::Out.Flush()

    if ( $Cloud -eq "AWS" ) {
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Receive Offload (IPv4)" -DisplayValue "Disabled"  -NoRestart -ErrorAction SilentlyContinue | Out-Default | Write-Host
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Send Offload V2 (IPv4)" -DisplayValue "Disabled" | Out-Default | Write-Host
    } elseif ( $Cloud -eq "Azure" ) {
        Set-NetAdapterAdvancedProperty $NICName -DisplayName "Large Send Offload Version 2 (IPv4)" -DisplayValue "Disabled" | Out-Default | Write-Host
    }
    [Console]::Out.Flush()

    # Check its worked
    Get-NetAdapterAdvancedProperty $NICName | Format-Table DisplayName , DisplayValue , RegistryKeyword ,    RegistryValue  | Out-Default | Write-Host
    [Console]::Out.Flush()

    Write-Host ("TCP Offloading disabled")
    [Console]::Out.Flush()
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
    Write-Host ("Creating database")

    # This requires the Powershell SQL Server cmdlets to be imported. This should already be done
    Try {
        # this should be unnecessary, hence commented out
        # Add-Type -Path "C:\Program Files\Microsoft SQL Server\110\SDK\Assemblies\Microsoft.SqlServer.Smo.dll"
        [System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Write-Host

        if ( -not $dbuser ) {
            Write-Host( "Trusted Connection" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; trusted_connection = true;"
        } else {
            Write-Host( "SQL Authentication" )
            $ConnectionString = "data source = $Server_name; initial catalog = master; User ID = $dbuser; Password = $dbpassword;"
        }
        $ConnectionString | Write-Host
        $ServerConnection = New-Object Microsoft.SqlServer.Management.Common.ServerConnection
        $ServerConnection.ConnectionString = $ConnectionString

        $SqlServer = New-Object Microsoft.SqlServer.Management.Smo.Server($ServerConnection)
    }
    Catch {
        $_ | Write-Host
        Write-Host ("Database connection failed. Is SQL Server running? Are login parameters correct?")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = New-Object Microsoft.SqlServer.Management.Smo.Database($SqlServer, $dbname)
    }
    Catch
    {
        $_ | Write-Host
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db.Create() | Write-Host
        Write-Host ($db.CreateDate)
    }
    Catch {
        $_ | Write-Host
        Write-Host ("Database creation failed. Its expected to fail on 2nd and subsequent EC2 instances or iterations")
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

    Write-Verbose ("Server_name = $server_name") | Write-Host
    Write-Verbose ("dbname = $dbname") | Write-Host
    Write-Verbose ("dbuser = $dbuser") | Write-Host

    # Delete database in SQL Server
    Write-Host ("Deleting database")

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
        $_ | Write-Host
        Write-RedOutput ("Database connection failed. Is SQL Server running? Are login parameters correct?")
        throw ("Error using SQL Server cmdlets")
    }

    Try {
        $db = $sqlserver.Databases.Item($dbname)
        if ( $db ) {
            Write-Host( "Drop any connections to database $dbname")
            Write-Host( "Current connections to $dbname = $($sqlserver.GetActiveDBConnectionCount($dbname))" )
            $sqlserver.KillAllProcesses($dbname) | Write-Host
            Write-Host( "Final connections to $dbname = $($sqlserver.GetActiveDBConnectionCount($dbname))" )
            Write-Host( "Dropping database $dbname")
            $db.drop() | Write-Host
            Write-Host( "Database dropped")
        } else {
            Write-RedOutput( "Database does not exist or database connection failed")
        }
    }
    Catch
    {
        $_ | Write-Host
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
    $singleWmi | Out-Default | Write-Host

    try {
        $uri = "ManagedComputer[@Name='$server']/ServerInstance[@Name='$instance']/ServerProtocol[@Name='$protocol']"
        $protocol = $singleWmi.GetSmoObject($uri)
    } catch {
        Write-Host( "Error using $instance. Retrying with first instance in the WMI object - $($SingleWmi.ServerInstances[0].Name)")
        $SavedException = $_
        try {
            $uri = "ManagedComputer[@Name='$server']/ServerInstance[@Name='$($SingleWmi.ServerInstances[0].Name)']/ServerProtocol[@Name='$protocol']"
            $protocol = $singleWmi.GetSmoObject($uri)
        } catch {
            Write-Host( "Throwing original exception")
            throw $SavedException
        }
    }

    if ( $protocol.IsEnabled -ne $enable )
    {
        $protocol.IsEnabled = $enable

        $protocol.Alter()  | Write-Host

        $protocol  | Write-Host

        return $true
    }
    return $false
}

##################################################################
# Function to get the SQL Server instance name
# Defaults to using MSSQLSERVER, if it exists
##################################################################
function Get-SqlServerInstanceName($server){

    $smo = 'Microsoft.SqlServer.Management.Smo.'

    $wmi = new-object ($smo + 'Wmi.ManagedComputer')

    $singleWmi = $wmi | where {$_.Name -eq $server}
    $singleWmi | Out-Default | Write-Host

    foreach ($Instance in $SingleWmi.ServerInstances) {
        if ( $Instance.Name -eq 'MSSQLSERVER') {
            return 'MSSQLSERVER'
        }
    }
    # If not found, return the first server instance
    return "SQLEXPRESS"
}

##################################################################
# Function to get the SQL Server Service name
# Defaults to using MSSQLSERVER, if it exists
##################################################################
function Get-SqlServerServiceName($server){

    $smo = 'Microsoft.SqlServer.Management.Smo.'

    $wmi = new-object ($smo + 'Wmi.ManagedComputer')

    $singleWmi = $wmi | where {$_.Name -eq $server}
    $singleWmi | Out-Default | Write-Host

    foreach ($Instance in $SingleWmi.ServerInstances) {
        if ( $Instance.Name -eq 'MSSQLSERVER') {
            return 'MSSQLSERVER'
        }
    }
    # If not found,
    return 'MSSQL$SQLEXPRESS'
}