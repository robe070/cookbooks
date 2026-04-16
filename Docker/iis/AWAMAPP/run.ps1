param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.0",

    [Parameter(Mandatory=$false)]
    [string]
    $VersionLabel = "V16 GA",

    [Parameter(Mandatory=$false)]
    [string]
    $SQLHost,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLPort = '1433',

    [Parameter(Mandatory=$false)]
    [string]
    $DbName = "AWAMAPP",

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

    [Parameter(Mandatory=$false)]
    [int]
    $StopTimeoutSeconds = 120,

    [Parameter(Mandatory=$true)]
    [ValidateSet('AWS','Azure')]
    [string]
    $Cloud
)

$ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
$WindowsEdition = 'windowsservercore'
$WindowsVersion = $ResolvedDockerLabel
$BaseTag = "$VersionNum-$WindowsVersion"
$BaseImageRepo = "lansalpc/vlbase-servercore"

Write-Host("Restart hns service to avoid this error: docker: Error response from daemon: failed to create endpoint LANSA-APP on network nat: failed during hnsCallRawResponse: hnsCall failed in Win32: The process cannot access the file because it is being used by another process. (0x20)")
restart-service hns
for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
        docker network disconnect -f nat LANSA-APP 2>$null
    } catch {
    }

    try {
        docker rm -f LANSA-APP 2>$null
    } catch {
    }

    $stillExists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq 'LANSA-APP' }
    if (-not $stillExists) {
        break
    }

    Start-Sleep -Seconds 2
}
$stillExists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq 'LANSA-APP' }
if ($stillExists) {
    Write-Host("WARNING: LANSA-APP container still exists after 3 remove attempts. Manual cleanup may be required.")
}

if ([string]::IsNullOrWhiteSpace($SQLHost)) {
    $SQLHost = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.IPAddress -notlike '169.254*' -and $_.InterfaceAlias -eq 'vEthernet (nat)'}).IPAddress
}

Write-Host("Using SQL_HOST='$SQLHost', SQL_PORT='$SQLPort', SQL_DSN='$DsnName' for container connectivity to SQL Server")
Write-Host("Recording the SQL connection details as environment variables for consistency with bootstrap.ps1")
$DBEnv = @()
$DBEnv += @('-e', "SQL_HOST=$SQLHost")
$DBEnv += @('-e', "SQL_PORT=$SQLPort")
$DBEnv += @('-e', "SQL_DSN=$DsnName")

$TraceEnv = @()
if ($Trace) { $TraceEnv = @('-e', 'X_RUN=ITRO:Y ITRL:4') }

$CloudEnv = @()
switch ($Cloud) {
    'Azure' {
        $RequiredEnvVars = @(
            'AZURE_TENANT_ID'
            'AZURE_CLIENT_ID'
            'AZURE_CLIENT_SECRET'
            'AZURE_LOCATION'
        )
    }
    'AWS' {
        $RequiredEnvVars = @(
            'AWS_ACCESS_KEY_ID'
            'AWS_SECRET_ACCESS_KEY'
            'AWS_DEFAULT_REGION'
        )
    }
    default {
        $RequiredEnvVars = @()
    }
}

foreach ($EnvVar in $RequiredEnvVars) {
    if ([string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable($EnvVar, 'Process'))) {
        throw "Required host environment variable '$EnvVar' is not set."
    }

    $CloudEnv += @('-e', $EnvVar)
}

if ($Cloud -eq 'AWS' -and -not [string]::IsNullOrWhiteSpace([System.Environment]::GetEnvironmentVariable('AWS_SESSION_TOKEN', 'Process'))) {
    $CloudEnv += @('-e', 'AWS_SESSION_TOKEN')
}

# $MetadataEnv = @()
# try {
#     $curlError = ''
#     $metadata = & curl.exe -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2017-08-01" --no-progress-meter 2>&1
#     $curlExitCode = $LASTEXITCODE
#     if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($metadata)) {
#         $metadata = $metadata.Trim()
#         $MetadataEnv = @('-e', "METADATA=$metadata")
#         Write-Host("Using host IMDS metadata injected via METADATA env var")
#         Write-Host("METADATA JSON: $metadata")
#     } else {
#         $curlError = ($metadata | Out-String).Trim()
#         throw "Host IMDS metadata not available. METADATA env var is mandatory. curl exit code: $curlExitCode. curl output: $curlError"
#     }
# } catch {
#     throw "Host IMDS metadata fetch failed. METADATA env var is mandatory. $($_.Exception.Message)"
# }

try {
    docker rm -f LANSA-APP 2>$null
} catch {
}

docker run --name LANSA-APP -it -e DEBUG=Y -e GITREPOPATH=c:\lansa -e GITBRANCH=debug/paas `
@DBEnv `
@TraceEnv `
@CloudEnv `
--stop-timeout $StopTimeoutSeconds `
-p 50080:80 -p 54545:4545 -p 58101:8101 `
-v c:\temp:c:\temp -v c:\secrets:c:\secrets -v C:\msi:c:\msi `
-v C:\dev\cookbooks\Docker:C:\docker `
--entrypoint powershell `
"$BaseImageRepo`:$BaseTag" `
-NoLogo -NoProfile -ExecutionPolicy Bypass `
-File c:\docker\iis\AWAMAPP\init.ps1 -server_name "tcp:$SQLHost,$SQLPort" -dbname $DbName -dbuser 'DBSetup' `
-dbpasswordpath 'c:\secrets\dbpassword.txt' -webuser 'PCXUSER2' -webpasswordpath 'c:\secrets\webpassword.txt' `
-MSIuri 'c:\msi\AWAMAPP_v16.0.26030_en-us.msi' -dbug -Cloud $Cloud
