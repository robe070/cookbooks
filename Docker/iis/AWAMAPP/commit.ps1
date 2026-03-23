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
    $VersionLabel = "V16 GA"
)

$ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
$WindowsEdition = 'windowsservercore'
$WindowsVersion = $ResolvedDockerLabel
$VersionLabelTag = ($VersionLabel -replace '\s+', '').ToLowerInvariant()
$ImageRepo = "lansalpc/vldemoapp-servercore"

Write-Host("Committing the LANSA App and replacing the installation script with c:\bootstrap.ps1")
docker stop LANSA-APP
docker commit `
  --change 'ENTRYPOINT ["powershell","-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File","C:\\bootstrap.ps1"]' `
  --change 'CMD []' `
  LANSA-APP "$ImageRepo`:$VersionNum-$WindowsVersion"

if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
  throw
}

docker tag "$ImageRepo`:$VersionNum-$WindowsVersion" "$ImageRepo`:$VersionLabelTag-$WindowsVersion"
