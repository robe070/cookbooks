param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.26030",

    [Parameter(Mandatory=$false)]
    [string]
    $SQLHost,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLPort,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLDsn,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

    [Parameter(Mandatory=$false)]
    [switch]
    $ByPassSQLServerDNSChecks
)

$ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
$WindowsVersion = $ResolvedDockerLabel
$ImageRepo = "lansalpc/vldemoapp-servercore"

try {
    docker rm -f LANSA-IMG 2>$null
} catch {
}
$envArgs = @('-e', 'DEBUG=Y')
if ($Trace) { $envArgs += @('-e', 'X_RUN=ITRO:Y') }
if ($SQLHost) { $envArgs += @('-e', "SQL_HOST=$SQLHost") }
if ($SQLPort) { $envArgs += @('-e', "SQL_PORT=$SQLPort") }
if ($SQLDsn) { $envArgs += @('-e', "SQL_DSN=$SQLDsn") }

$bootstrapArgs = @('-File', 'C:\bootstrap.ps1')
if ($ByPassSQLServerDNSChecks) { $bootstrapArgs += @('-ByPassSQLServerDNSChecks') }

docker run --name LANSA-IMG -it `
  @envArgs `
  -p 50080:80 -p 54545:4545  `
  -v c:\temp:c:\temp `
  --entrypoint powershell `
  "$ImageRepo`:$VersionNum-$WindowsVersion" `
  -NoLogo -NoProfile -ExecutionPolicy Bypass `
  @bootstrapArgs
