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
    $Cloud
)
if ( $DockerLabel -eq 'all' ){
    .\build.ps1 ltsc2025 -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
} else {
    .\build.ps1 $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
}
