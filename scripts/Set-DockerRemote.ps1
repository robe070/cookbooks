#Enter a space for strings or 0 for numbers to take default values
Param(
    [Parameter(Mandatory)]
        [string] $HostIpAddress='dummy so will prompt but allows no entry and always overwritten',
    [Parameter(Mandatory)]
        [decimal] $HostIpPort=2376,
    [Parameter(Mandatory)]
        [string] $CertSubDir='dummy so will prompt but allows no entry and always overwritten'
)

if ( [string]::IsNullOrWhiteSpace($HostIpAddress) ) {
    $HostIpAddress = '52.187.239.172'
}

if ( $HostIpPort -eq 0 ) {
    $HostIpPort = 2376
}

if ( [string]::IsNullOrWhiteSpace($CertSubDir) ) {
    $CertPath = 'C:\certs\client'
} else {
    $CertPath = "C:\certs\client\$CertSubDir"
}

$env:DOCKER_HOST="tcp://$($HostIpAddress):$HostIpPort"
$env:DOCKER_TLS_VERIFY='1'
$env:DOCKER_CERT_PATH=$CertPath
