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
