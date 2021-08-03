<#
.SYNOPSIS
Write a script to the target machine that OOBE will call to enable the built-in Administrator account (i.e. SID 500, regardless of its name).

.DESCRIPTION
OOBE supports running a custom script after setup completes named C:\Windows\Setup\Scripts\SetupComplete.cmd (see https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/add-a-custom-script-to-windows-setup).
However, Azure's provisioning process uses this script (overwriting if necessary) to bootstrap its own
OOBE process. Luckily, Azure's OOBE process leaves a hook for us at the end of its process by running the script
C:\OEM\SetupComplete2.cmd, if present.

This script writes a SetupComplete2.ps1 that enables the built-in Administrator account. It does so by searching for SID 500, so that the script
works even if the Administrator account is renamed (which Azure does). Then a SetupComplete2.cmd is written to call our PowerShell script, since
the hook requires the file to be named "SetupCompelete2.cmd".

.NOTES
To support further downstream customization, this script looks for a C:\OEM\SetupComplete3.cmd, and if found, runs it.
#>

$ErrorActionPreference = "Stop"
Set-StrictMode -version Latest


$path = "$($Env:SystemRoot)\OEM"

New-Item -ItemType Directory -Path $path -Force

# Use single-quote for the here-string so the text isn't interpolated
@'
$adminAccount = Get-WmiObject Win32_UserAccount -filter "LocalAccount=True" | ?{$_.SID -Like "S-1-5-21-*-500"}
if($adminAccount.Disabled)
{
    Write-Host "Admin account was disabled. Enabling the Admin account."
    $adminAccount.Disabled = $false
    $adminAccount.Put()
}
else
{
    Write-Host "Admin account is enabled."
}

# Since we are using SetupComplete2.cmd, add a hook for future us to use SetupComplete3.cmd
if (Test-Path $Env:SystemRoot\OEM\SetupComplete3.cmd)
{
    & $Env:SystemRoot\OEM\SetupComplete3.cmd
}
'@ | Out-File -Encoding ASCII -FilePath "$path\SetupComplete2.ps1"

"powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File %~dp0SetupComplete2.ps1" | Out-File -Encoding ASCII -FilePath "$path\SetupComplete2.cmd"