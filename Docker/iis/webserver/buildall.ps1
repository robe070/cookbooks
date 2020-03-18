param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('1903', '1909', 'ltsc2019', 'all')]
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
    .\build.ps1 1909 -Hyperv -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    .\build.ps1 ltsc2019 -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    .\build.ps1 1903 -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
} else {
    .\build.ps1 $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
}