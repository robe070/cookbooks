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

try {
    $ClearCacheCmd = ""
    if ( $ClearCache ) {
        $ClearCacheCmd = "--no-cache=true"
    }

    $HypervCmd = ""
    if ( $Hyperv ) {
        $HypervCmd = '-hyperv'
    }
    Push-Location base -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location vlweb -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location webserver -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    Pop-Location -StackName Docker

    Push-Location addapp -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -Hyperv:$Hyperv -ImageVersion $ImageVersion -ClearCache:$ClearCache
    Pop-Location -StackName Docker

} catch {
    $_
    Pop-Location -StackName Docker
    throw
} finally {
    Write-Host("************************************************************************************************")
}