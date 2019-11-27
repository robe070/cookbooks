Param(
    [Parameter(Mandatory)]
        [string] $HostIpAddress
)

$env:DOCKER_HOST="tcp://$($HostIpAddress):2376"
$env:DOCKER_TLS_VERIFY='1'
$env:DOCKER_CERT_PATH='C:\certs\client'
