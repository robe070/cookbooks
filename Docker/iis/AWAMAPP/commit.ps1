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
    [int]
    $StopTimeoutSeconds = 120
)

$ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
$WindowsEdition = 'windowsservercore'
$WindowsVersion = $ResolvedDockerLabel
$VersionLabelTag = ($VersionLabel -replace '\s+', '').ToLowerInvariant()
$ImageRepo = "lansalpc/vldemoapp-servercore"
$TargetImage = "$ImageRepo`:$VersionNum-$WindowsVersion"

$containerExists = docker ps -a --format "{{.Names}}" | Where-Object { $_ -eq 'LANSA-APP' }
if (-not $containerExists) {
  throw "LANSA-APP container not found. Run .\run.ps1 first."
}

$containerState = docker inspect -f "{{.State.Status}}" LANSA-APP
if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
  throw
}

if ($containerState -eq 'running') {
  Write-Host("Stopping LANSA-APP with timeout ${StopTimeoutSeconds}s before commit")
  docker stop -t $StopTimeoutSeconds LANSA-APP
  if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw
  }

  $containerState = docker inspect -f "{{.State.Status}}" LANSA-APP
  if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
    throw
  }
}

if ($containerState -ne 'exited') {
  throw "LANSA-APP is '$containerState'. Commit expects a cleanly stopped container."
}

Write-Host("Committing the LANSA App and replacing the installation script with c:\bootstrap.ps1")
docker commit `
  --change 'ENTRYPOINT ["powershell","-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\bootstrap.ps1"]' `
  --change 'CMD []' `
  LANSA-APP $TargetImage

if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
  throw
}

docker tag $TargetImage "$ImageRepo`:$VersionLabelTag-$WindowsVersion"
