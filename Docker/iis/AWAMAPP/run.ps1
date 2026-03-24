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
    $SQLPort,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

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
if ([string]::IsNullOrWhiteSpace($SQLPort)) {
    $SQLPort = "1433"
}

$TraceEnv = @()
if ($Trace) { $TraceEnv = @('-e', 'X_RUN=ITRO:Y ITRL:4') }

docker run --name LANSA-APP -it -e DEBUG=Y -e GITREPOPATH=c:\lansa -e GITBRANCH=debug/paas `
@TraceEnv `
-p 50080:80 -p 54545:4545 -p 58101:8101 `
-v c:\temp:c:\temp -v c:\secrets:c:\secrets -v C:\msi:c:\msi `
-v C:\dev\cookbooks\Docker:C:\docker `
--entrypoint powershell `
"$BaseImageRepo`:$BaseTag" `
-NoLogo -NoProfile -ExecutionPolicy Bypass `
-File c:\docker\iis\base\init.ps1 -server_name "tcp:$SQLHost,$SQLPort" -dbname 'AWAMAPP' -dbuser 'DBSetup' `
-dbpasswordpath 'c:\secrets\dbpassword.txt' -webuser 'PCXUSER2' -webpasswordpath 'c:\secrets\webpassword.txt' `
-MSIuri 'c:\msi\AWAMAPP_v16.0.26030_en-us.msi' -dbug -Cloud $Cloud
