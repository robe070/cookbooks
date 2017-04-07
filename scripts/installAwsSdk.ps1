# When called from a Packer script, $env:TEMP was empty. Hence why I have the option to pass a temp location.
if ([string]::IsNullOrEmpty( $args[0]))
{
   $tempFolder = $env:TEMP
}
else
{
   $tempFolder = $args[0]
}

$source = "http://sdk-for-net.amazonwebservices.com/latest/AWSToolsAndSDKForNet.msi"
$destination = Join-Path -Path $tempFolder -ChildPath "AWSToolsAndSDKForNet.msi"
$wc = New-Object system.net.webclient
$wc.downloadFile( $source, $destination ) | Write-Output
Run-ExitCode 'msiexec' @('/quiet', '/i', $destination)

Write-Output "$(Log-Date) AWS SDK for .Net installed"
