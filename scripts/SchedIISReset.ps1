<#
.SYNOPSIS

.EXAMPLE

#>

Get-Date
try {
    cmd /c exit 0 # Set LASTEXITCODE
    Write-Output( "Resetting..." )
    Start-Process "iisreset.exe" -ArgumentList @("/restart", "/noforce", "/timeout:60") -NoNewWindow -Wait

} catch {
    $_
    cmd /c exit -1 # Set LASTEXITCODE
    return
}
Get-Date
Write-Output( "Success" )