param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all' )]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.0",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace
)

try {
    $ErrorActionPreference = 'Stop'

    Write-Host("************************************************************************************************")
    pwd | Out-Default | Write-Host
    Write-Host("DockerLabel=$DockerLabel")
    Write-Host("VersionNum=$VersionNum")
    Write-Host("ClearCache=$ClearCache")
    Write-Host("Trace=$Trace")
    Write-Host("************************************************************************************************")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }

    $WindowsRepo = "mcr.microsoft.com/windows/servercore/iis"
    $WindowsEdition = "windowsservercore"
    $WindowsVersion = $ResolvedDockerLabel

    $VersionLabel = "V16 GA"
    $VersionLabelTag = ($VersionLabel -replace '\s+', '').ToLowerInvariant()
    $BuildDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $VcsRef = (git rev-parse HEAD).Trim()

    Write-Host ("Copy seed scripts that are required to get the cookbooks git repo installed in the image")

    $ScriptDir = '..\..\..\scripts'
    Copy-Item $(Join-Path $ScriptDir 'dot-CommonTools.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host
    Copy-Item $(Join-Path $ScriptDir 'getchoco.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host
    Copy-Item $(Join-Path $ScriptDir 'installGit.ps1') . -Force -verbose -ErrorAction 'Stop' | Out-Default | Write-Host

    $ClearCacheCmd = ""
    if ( $ClearCache ) {
        $ClearCacheCmd = "--no-cache=true"
    }

    Write-Host ("Ensure we have the latest Windows image")
    docker image pull "$WindowsRepo`:$WindowsEdition-$WindowsVersion"

    Write-Host( "Build the new Docker image")
    $Variant = if ( $WindowsEdition -eq 'windowsservercore' ) { 'servercore' } else { $WindowsEdition }
    $ImageRepo = "lansalpc/vlbase-$Variant"
    docker image build `
        --build-arg WINDOWS_REPO=$WindowsRepo `
        --build-arg WINDOWS_EDITION=$WindowsEdition `
        --build-arg WINDOWS_VERSION=$WindowsVersion `
        --build-arg VERSION_NUM=$VersionNum `
        --build-arg VERSION_LABEL=$VersionLabel `
        --build-arg BUILD_DATE=$BuildDate `
        --build-arg VCS_REF=$VcsRef `
        $ClearCacheCmd `
        --tag "$ImageRepo`:$VersionNum-$WindowsVersion" `
        --tag "$ImageRepo`:$VersionLabelTag-$WindowsVersion" `
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
