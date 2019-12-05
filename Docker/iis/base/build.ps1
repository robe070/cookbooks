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

Write-Host ("Copy seed scripts that are required to get the cookbooks git repo installed in the image")

$ScriptDir = '..\..\..\scripts'
Copy-Item $(Join-Path $ScriptDir 'dot-CommonTools.ps1') . -Force -verbose -ErrorAction 'Stop'
Copy-Item $(Join-Path $ScriptDir 'getchoco.ps1') . -Force -verbose -ErrorAction 'Stop'
Copy-Item $(Join-Path $ScriptDir 'installGit.ps1') . -Force -verbose -ErrorAction 'Stop'

$ClearCacheCmd = ""
if ( $ClearCache ) {
    $ClearCacheCmd = "--no-cache=true"
}

$HypervCmd = ""
if ( $Hyperv ) {
    $HypervCmd = '--isolation=hyperv'
}

docker image build --build-arg WINDOWS_VERSION=$WINDOWS_VERSION $ClearCacheCmd $HypervCmd --tag lansalpc/iis/base:$WINDOWS_VERSION-$ImageVersion .