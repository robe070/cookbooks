param (
    [Parameter(Mandatory=$false)]
    [string]
    $WINDOWS_VERSION = "windowsservercore-1903",

    [Parameter(Mandatory=$false)]
    [string]
    $ImageVersion = "14.99",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache
)

Write-Host ("Copy seed scripts that are required to get the cookbooks git repo installed in the image")

$ScriptDir = '..\..\scripts'
Copy-Item $(Join-Path $ScriptDir 'dot-CommonTools.ps1') . -Force -verbose
Copy-Item $(Join-Path $ScriptDir 'getchoco.ps1') . -Force -verbose
Copy-Item $(Join-Path $ScriptDir 'installGit.ps1') . -Force -verbose

$ClearCacheCmd = ""
if ( $ClearCache ) {
    $ClearCacheCmd = "--no-cache=true"
}
docker image build --build-arg WINDOWS_VERSION=$WINDOWS_VERSION $ClearCacheCmd --tag lansalpc/scalable-base:$ImageVersion .