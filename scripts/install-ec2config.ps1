# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir)
{
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}

Write-Output "$(Log-Date) Install EC2Config Service"

$url = "https://ec2-downloads-windows.s3.amazonaws.com/EC2Config/EC2Install.zip"
$output = "c:\Ec2Install.zip"
$destination = "c:\temp"
(New-Object System.Net.WebClient).DownloadFile($url, $output)

Add-Type -assembly "system.io.compression.filesystem"

[io.compression.zipfile]::ExtractToDirectory($output, $destination)

# This is not run quietly because it failed to install version 3.9.359. So we must install manually and check it works - look in %TEMP%
cmd /c 'c:\temp\Ec2Install.exe'