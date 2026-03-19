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
if ( $DockerLabel -eq 'all' ){
    .\build.ps1 ltsc2025 -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
} else {
    .\build.ps1 $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
}


