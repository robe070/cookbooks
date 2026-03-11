param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [switch]
    $Hyperv,

    [Parameter(Mandatory=$false)]
    [string]
    $ImageVersion = "14.99",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache
)

try {
    $ErrorActionPreference = 'Stop'

    Write-Host("************************************************************************************************")
    pwd | Out-Default | Write-Host
    Write-Host("DockerLabel=$DockerLabel")
    Write-Host("ImageVersion=$ImageVersion")
    Write-Host("ClearCache=$ClearCache")
    Write-Host("Hyperv=$Hyperv")
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "Host Windows Version {0} {1}.{2}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR
    Write-Host("************************************************************************************************")

    Write-Host ("Note: the host Windows build must be compatible with the container base image.")
    Write-Host("If you see a version incompatibility error, use a newer host. Using Hyper-V isolation does not solve version incompatibility issues on Windows")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
    $WINDOWS_VERSION = 'windowsservercore-' + $ResolvedDockerLabel
    $BASE_TAG = $ImageVersion + '-' + $WINDOWS_VERSION

    $ClearCacheCmd = ""
    if ( $ClearCache ) {
        $ClearCacheCmd = "--no-cache=true"
    }

    $HypervCmd = ""
    if ( $Hyperv ) {
        Write-Host("Using Hyper-V isolation for better compatibility at the cost of higher resource usage. Note that the host Windows build must be compatible with the container base image even when using Hyper-V isolation.")
        $HypervCmd = '--isolation=hyperv'
    } else {
        Write-Host("Using default isolation (process) which has lower resource usage but may have compatibility issues if the host Windows build is not compatible with the container base image.")
    }

    docker image build --build-arg BASE_TAG=$BASE_TAG $ClearCacheCmd $HypervCmd --tag lansalpc/iis-webserver:$ImageVersion-$WINDOWS_VERSION .
     if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_
    throw
} finally {
    Write-Host("************************************************************************************************")
}



