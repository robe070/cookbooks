<#
.SYNOPSIS

Run Chef so that we can run as administrator. Cannot directly run from the Cloud Formation script

#>
param(
[String]$FullPath='c:\opscode\chef\bin\chef-client.bat',
[String]$WorkingDirectory='C:\recipes\chef-repo\cookbooks',
[String]$cookbook='VLWebServer',
[String]$Arguments="-z -o $cookbook"
)

# Put first output on a new line in cfn_init log file
Write-Output ("`r`n")

# $DebugPreference = "Continue"

Write-Debug ("Cookbook = $cookbook")

$ProcessInfo = New-Object System.Diagnostics.ProcessStartInfo 
$ProcessInfo.FileName = $FullPath 
$ProcessInfo.WorkingDirectory = $WorkingDirectory
$ProcessInfo.RedirectStandardError = $true 
$ProcessInfo.RedirectStandardOutput = $true 
$ProcessInfo.UseShellExecute = $false 
$ProcessInfo.Arguments = $Arguments 
$Process = New-Object System.Diagnostics.Process 
$Process.StartInfo = $ProcessInfo 
$Process.Start() | Out-Null 
$std_output = $Process.StandardOutput.ReadToEnd() 
$std_error = $Process.StandardError.ReadToEnd() 
$Process.WaitForExit() 
Write-Output "Standard Output..."
$std_output 
if ( $std_error) {
    Write-Output "Standard Error..."
    $std_error
}

if ( $Process.ExitCode -eq 0 )
{
    Write-Output ( "Installation successful")
}
else
{
    Write-Output ( "Installation failed")
}
exit $Process.ExitCode