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
    $ClearCache,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLHost,

    [Parameter(Mandatory=$false)]
    [string]
    $SQLPort,

    [Parameter(Mandatory=$true)]
    [ValidateSet('AWS','Azure')]
    [string]
    $Cloud
)

try {
    $ErrorActionPreference = 'Stop'

    Write-Host("************************************************************************************************")
    pwd | Out-Default | Write-Host
    Write-Host("DockerLabel=$DockerLabel")
    Write-Host("VersionNum=$VersionNum")
    Write-Host("ClearCache=$ClearCache")
    Write-Host("Trace=$Trace")
    Write-Host("Cloud=$Cloud")
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    "Host Windows Version {0} {1}.{2}" -f $cv.DisplayVersion, $cv.CurrentBuild, $cv.UBR
    Write-Host("************************************************************************************************")

    $ResolvedDockerLabel = if ( $DockerLabel -eq 'all' ) { 'ltsc2025' } else { $DockerLabel }
    $WindowsEdition = 'windowsservercore'
    $WindowsVersion = $ResolvedDockerLabel

    $VersionLabel = "V16 GA"

    .\run.ps1 -DockerLabel $ResolvedDockerLabel -VersionNum $VersionNum -VersionLabel $VersionLabel -SQLHost $SQLHost -SQLPort $SQLPort -Cloud $Cloud -Trace:$Trace
    if ( $LASTEXITCODE -and $LASTEXITCODE -ne 0) {
        throw
    }
} catch {
    $_
    throw
} finally {
    Write-Host("************************************************************************************************")
}
