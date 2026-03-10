param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all' )]
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
    Write-Host("HyperV=$Hyperv")
    Write-Host("************************************************************************************************")

    Write-Host ("Note: the host Windows build must be compatible with the container base image.")
    Write-Host("If you see a version incompatibility error, use a newer host. Using Hyper-V isolation does not solve version incompatibility issues on Windows")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
    $WINDOWS_VERSION = 'windowsservercore-' + $ResolvedDockerLabel

    Write-Host ("Copy seed scripts that are required to get the cookbooks git repo installed in the image")

    $ScriptDir = '..\..\..\scripts'
    Copy-Item $(Join-Path $ScriptDir 'dot-CommonTools.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host
    Copy-Item $(Join-Path $ScriptDir 'getchoco.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host
    Copy-Item $(Join-Path $ScriptDir 'installGit.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host

    $ClearCacheCmd = ""
    if ( $ClearCache ) {
        $ClearCacheCmd = "--no-cache=true"
    }

    $HypervCmd = ""
    if ( $Hyperv ) {
        $HypervCmd = '--isolation=hyperv'
    }

    Write-Host ("Ensure we have the latest Windows image")
    docker image pull  mcr.microsoft.com/windows/servercore/iis:$WINDOWS_VERSION

    Write-Host( "Build the new Docker image")
    docker image build --build-arg WINDOWS_VERSION=$WINDOWS_VERSION $ClearCacheCmd $HypervCmd --tag lansalpc/iis-base:$ImageVersion-$WINDOWS_VERSION .

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_
    throw
} finally {
    Write-Host("************************************************************************************************")
}



