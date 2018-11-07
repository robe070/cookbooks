<#
.SYNOPSIS

Post to the test LANSA server module in order to prestart the LANSA environment to speed up the first call

.EXAMPLE

#>
param (
    [Parameter(Mandatory=$false)]
        [string]
        $dns = 'localhost',
    [Parameter(Mandatory=$false)]
        [string]
        $port = '8504',
    [Parameter(Mandatory=$false)]
        [string]
        $Partition = 'ils',
    [Parameter(Mandatory=$false)]
        [string]
        $webalias = 'licensing'
)
cmd /c exit 0 # Set LASTEXITCODE
try {
    Write-Output( "Prestarting..." )

    $url = "http://$($dns):$port/$webalias/lansaweb?w=XVLSMTST&r=GETRESPONSE&vlweb=1&part=$partition&lang=ENG"
    $response = Invoke-WebRequest -Uri $url
    $ResponseCode = $response.StatusCode
    switch ($ResponseCode) {
        200 { }
        default { throw "Error $ResponseCode running $url" }
    }
} catch {
    Write-Output ( "Exception running $url")
    $_
    cmd /c exit -1 # Set LASTEXITCODE
    return
}
Write-Output( "Success")