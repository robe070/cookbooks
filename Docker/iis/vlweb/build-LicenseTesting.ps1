param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.0",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache
)

try {
    $ErrorActionPreference = 'Stop'

    Write-Host("************************************************************************************************")
    pwd | Out-Default | Write-Host
    Write-Host("DockerLabel=$DockerLabel")
    Write-Host("VersionNum=$VersionNum")
    Write-Host("ClearCache=$ClearCache")
    Write-Host("************************************************************************************************")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
    $WindowsEdition = 'windowsservercore'
    $WindowsVersion = $ResolvedDockerLabel
    $BaseTag = "$VersionNum-$WindowsVersion"

    $VersionLabel = "V16 GA"
    $VersionLabelTag = ($VersionLabel -replace '\s+', '').ToLowerInvariant()

    $ClearCacheCmd = ""
    if ( $ClearCache ) {
        $ClearCacheCmd = "--no-cache=true"
    }

    $ImageRepo = "lansalpc/iis/licensetesting"
    docker image build `
        --build-arg BASE_TAG=$BaseTag `
        $ClearCacheCmd `
        --tag "$ImageRepo`:$VersionNum-$WindowsVersion" `
        --tag "$ImageRepo`:$VersionLabelTag-$WindowsVersion" `
        -f LicenseTesting.dockerfile `
        .
    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_
    throw
} finally {
    Write-Host("************************************************************************************************")
}


