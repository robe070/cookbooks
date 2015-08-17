# When called from a Packer script, $env:TEMP was empty. Hence why I have the option to pass a temp location.
if ([string]::IsNullOrEmpty( $args[0]))
{
   $tempFolder = $env:TEMP
}
else
{
   $tempFolder = $args[0]
}

$source = "https://s3.amazonaws.com/aws-cli/AWSCLI64.msi"
$destination = Join-Path -Path $tempFolder -ChildPath "AWSCLI64.msi"
$wc = New-Object system.net.webclient
$wc.downloadFile( $source, $destination ) | Write-Output
msiexec /quiet /i $destination | Write-Output

Write-Output "$(Log-Date) AWS CLI installed"
