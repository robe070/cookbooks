## this is an alternative to using ServiceMonitor

param(
    [Switch]$ByPassSQLServerDNSChecks
)

# log entry to make invocation explicit in container logs
Write-Host ("bootstrap.ps1 starting (ByPassSQLServerDNSChecks={0})" -f $ByPassSQLServerDNSChecks.IsPresent)

# SQL_DSN overrides the System DSN name (default: Docker)
# fail fast on missing SQL_HOST / SQL_PORT, update DSN, and validate connectivity
$SqlHost = $env:SQL_HOST
$SqlPort = $env:SQL_PORT
$DsnName = $env:SQL_DSN
if ([string]::IsNullOrWhiteSpace($DsnName)) {
    $DsnName = "Docker"
}

if (-not $ByPassSQLServerDNSChecks) {
    Write-Host ("SQL env vars: SQL_HOST='{0}', SQL_PORT='{1}', SQL_DSN='{2}'" -f $SqlHost, $SqlPort, $DsnName)

    if ([string]::IsNullOrWhiteSpace($SqlHost)) {
        throw "SQL_HOST is required."
    }

    if ([string]::IsNullOrWhiteSpace($SqlPort)) {
        throw "SQL_PORT is required."
    }

    $SqlPortInt = 0
    if (-not [int]::TryParse($SqlPort, [ref]$SqlPortInt)) {
        throw "SQL_PORT must be an integer."
    }

    try {
        $resolved = [System.Net.Dns]::GetHostAddresses($SqlHost)
        if ($null -eq $resolved -or $resolved.Count -eq 0) {
            throw "No addresses returned."
        }
    } catch {
        throw "SQL_HOST '$SqlHost' did not resolve. $_"
    }

    $tcpClient = New-Object System.Net.Sockets.TcpClient
    try {
        $async = $tcpClient.BeginConnect($SqlHost, [int]$SqlPort, $null, $null)
        if (-not $async.AsyncWaitHandle.WaitOne(5000, $false)) {
            throw "Timed out connecting to ${SqlHost}:${SqlPort}."
        }
        $tcpClient.EndConnect($async)
    } catch {
        throw "SQL_HOST '$SqlHost' and SQL_PORT '$SqlPort' are not reachable. $_"
    } finally {
        $tcpClient.Close()
    }

    $serverValue = "$SqlHost,$SqlPort"
    if (Get-Command Get-OdbcDsn -ErrorAction SilentlyContinue) {
        try {
            $dsn = Get-OdbcDsn -Name $DsnName -DsnType "System" -ErrorAction Stop
        } catch {
            throw "System DSN '$DsnName' not found. $_"
        }

        # Update DSN to use the resolved host/port
        try {
            if (Get-Command Set-OdbcDsn -ErrorAction SilentlyContinue) {
                Set-OdbcDsn -Name $DsnName -DsnType "System" -SetPropertyValue @("Server=$serverValue", "Port=$SqlPort") -ErrorAction Stop
            } else {
                throw "Set-OdbcDsn cmdlet not available."
            }
        } catch {
            throw "Failed to update System DSN '$DsnName' with Server=$serverValue Port=$SqlPort. $_"
        }
    } else {
        $dsnRegPath = "HKLM:\Software\ODBC\ODBC.INI\$DsnName"
        if (-not (Test-Path $dsnRegPath)) {
            throw "System DSN '$DsnName' not found at $dsnRegPath."
        }

        Set-ItemProperty -Path $dsnRegPath -Name "Server" -Value $serverValue -Type String
        Set-ItemProperty -Path $dsnRegPath -Name "Port" -Value $SqlPort -Type String
        Set-ItemProperty -Path $dsnRegPath -Name "ServerName" -Value $serverValue -Type String
    }

    # Test ODBC connectivity using the DSN (expects credentials to be in DSN or trusted auth)
    try {
        $conn = New-Object System.Data.Odbc.OdbcConnection("DSN=$DsnName;")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT 1"
        [void]$cmd.ExecuteScalar()
        $conn.Close()
    } catch {
        throw "ODBC test failed for DSN '$DsnName'. $_"
    }
} else {
    Write-Host "Bypassing SQL Server DNS/ODBC checks (ByPassSQLServerDNSChecks set)."
}

# copy process-level environment variables to machine level
foreach($key in [System.Environment]::GetEnvironmentVariables('Process').Keys) {
    if ($null -eq [System.Environment]::GetEnvironmentVariable($key, 'Machine')) {
        $value = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, $value, 'Machine')
    }
}

# echo the IIS log to the console:
Start-Service W3SVC
Invoke-WebRequest http://localhost -UseBasicParsing | Out-Null
netsh http flush logbuffer | Out-Null
Get-Content -path 'C:\iislog\W3SVC\u_extend1.log' -Tail 1 -Wait
