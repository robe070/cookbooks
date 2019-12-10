param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('1903', '1909', 'ltsc2019', 'ltsc2016')]
    [string]
    $DockerLabel='1903',

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

$ErrorActionPreference = 'Stop'

Write-Host ("Note: if you get a message similar to the following the host computer needs to be a later build than the one being constructed. So 1909 can't be built on 1903, but ltsc2016 and ltsc2019 can be built. hyperv seems to make no difference")
Write-Host("a Windows version 10.0.18363-based image is incompatible with a 10.0.18362 host")

$WINDOWS_VERSION = 'windowsservercore-' + $DockerLabel
$BASE_TAG = $WINDOWS_VERSION + '-' + $ImageVersion

$ClearCacheCmd = ""
if ( $ClearCache ) {
    $ClearCacheCmd = "--no-cache=true"
}

$HypervCmd = ""
if ( $Hyperv ) {
    $HypervCmd = '--isolation=hyperv'
}

docker image build --build-arg BASE_TAG=$BASE_TAG $ClearCacheCmd $HypervCmd --tag lansalpc/iis/vlweb:$WINDOWS_VERSION-$ImageVersion .