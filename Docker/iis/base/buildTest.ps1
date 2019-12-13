param (
    [Parameter(Mandatory=$false)]
    [string]
    $WINDOWS_VERSION = "windowsservercore-1909",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache
)

$ClearCacheCmd = ""
if ( $ClearCache ) {
    $ClearCacheCmd = "--no-cache=true"
}
docker image build --build-arg WINDOWS_VERSION=$WINDOWS_VERSION $ClearCacheCmd --tag lansalpc/iis/base:test -f DockerfileTest.dockerfile .