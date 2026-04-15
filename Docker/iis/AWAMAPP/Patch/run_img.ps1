param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.26030.1",

    [Parameter(Mandatory=$false)]
    [string]
    $SQLHost,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLPort = "1433",

    [Parameter(Mandatory=$false)]
    [string]
    $SQLDsn,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

    [Parameter(Mandatory=$false)]
    [switch]
    $ByPassSQLServerDNSChecks,
    
    [Parameter(Mandatory=$true)]
    [ValidateSet('AWS','Azure')]
    [string]
    $Cloud 
)

$ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
$WindowsVersion = $ResolvedDockerLabel
$ImageRepo = "lansalpc/vldemoapp-servercore"

try {
    docker rm -f LANSA-PATCH 2>$null
} catch {
}

if ([string]::IsNullOrWhiteSpace($SQLHost)) {
    $SQLHost = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -eq 'vEthernet (nat)'}).IPAddress
}

$envArgs = @('-e', 'DEBUG=Y')
if ($Trace) { $envArgs += @('-e', 'X_RUN=ITRO:Y ITRL:4') }
if ($SQLHost) { $envArgs += @('-e', "SQL_HOST=$SQLHost") }
if ($SQLPort) { $envArgs += @('-e', "SQL_PORT=$SQLPort") }
if ($SQLDsn) { $envArgs += @('-e', "SQL_DSN=$SQLDsn") }

$bootstrapArgs = @('-File', 'C:\bootstrap.ps1')
if ($ByPassSQLServerDNSChecks) { $bootstrapArgs += @('-ByPassSQLServerDNSChecks') }

docker run --name LANSA-PATCH -it `
  @envArgs `
  -p 50080:80 -p 54545:4545  `
  -v c:\temp:c:\temp `
  -v C:\dev\cookbooks\Docker:C:\docker `
  --entrypoint powershell `
  "$ImageRepo`:$VersionNum-$WindowsVersion-$Cloud" `
  -NoLogo -NoProfile -ExecutionPolicy Bypass `
  @bootstrapArgs
