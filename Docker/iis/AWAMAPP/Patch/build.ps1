param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "1",

    [Parameter(Mandatory=$false)]
    [string]
    $ParentVersionNum = "16.0.26030",

    [Parameter(Mandatory=$false)]
    [string]
    $ImageRepo = "lansalpc/vldemoapp-servercore",

    # [Parameter(Mandatory=$false)]
    # [string]
    # $DllName = "X_PDFMS.DLL",

    [Parameter(Mandatory=$false)]
    [switch]
    $NoCache
)

try {
    $ErrorActionPreference = 'Stop'

    Write-Host("************************************************************************************************")
    pwd | Out-Default | Write-Host
    Write-Host("DockerLabel=$DockerLabel")
    Write-Host("VersionNum=$VersionNum")
    Write-Host("ParentVersionNum=$ParentVersionNum")
    Write-Host("ImageRepo=$ImageRepo")
    # Write-Host("DllName=$DllName")
    Write-Host("NoCache=$NoCache")
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "Host Windows Version {0} {1}.{2}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR
    Write-Host("************************************************************************************************")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
    $WindowsVersion = $ResolvedDockerLabel
    $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $DockerfilePath = Join-Path $ScriptDir 'Dockerfile'
    # $DllPath = Join-Path $ScriptDir $DllName
    $ParentImage = "$ImageRepo`:$ParentVersionNum-$WindowsVersion"
    $PatchedImage = "$ImageRepo`:$ParentVersionNum.$VersionNum-$WindowsVersion"

    if (-not (Test-Path -LiteralPath $DockerfilePath -PathType Leaf)) {
        throw "Dockerfile not found: $DockerfilePath"
    }

    # if (-not (Test-Path -LiteralPath $DllPath -PathType Leaf)) {
    #     throw "Patch DLL not found: $DllPath"
    # }

    Write-Host("ParentImage=$ParentImage")
    Write-Host("PatchedImage=$PatchedImage")

    $BuildArgs = @(
        'build'
        '--build-arg'
        "BASE_IMAGE=$ParentImage"
        '--tag'
        $PatchedImage
    )

    if ($NoCache) {
        $BuildArgs += '--no-cache'
    }

    $BuildArgs += @(
        '--file'
        $DockerfilePath
        $ScriptDir
    )

    & docker @BuildArgs

    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_
    throw
} finally {
    Write-Host("************************************************************************************************")
}
