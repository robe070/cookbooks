param(
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
    Push-Location base -StackName Docker
    .\build.ps1 $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location webserver -StackName Docker
    .\build.ps1 $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location vlweb -StackName Docker
    .\build.ps1 $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location addapp -StackName Docker
    .\build.ps1 $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache
    Pop-Location -StackName Docker

} catch {
    Pop-Location -StackName Docker
}
