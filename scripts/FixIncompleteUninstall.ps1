Write-Host "Note that this code did not fix the issue I had. Use the Microsoft tool first before this MicrosoftProgram_Install_and_Uninstall.meta.cab"
$productName = "C:\Program Files (x86)\Rob\WAM Application\*"  # this should basically match against your previous
# installation path. Make sure that you don't mess with other components used
# by any other MSI package

$components = Get-ChildItem -Path HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Components\
$count = 0

$ErrorActionPreference = "Stop"
try {
    foreach ($c in $components)
    {
        foreach($p in $c.Property)
        {
            $propValue = (Get-ItemProperty "Registry::$($c.Name)" -Name "$($p)")."$($p)"
            if ($propValue -like $productName)
            {
                Write-Output "Property = $propValue"
                Write-Output "Removing Registry::$($c.Name)"
                $count++
                Remove-Item "Registry::$($c.Name)" -Recurse
            }
        }
    }
} catch {
    $_
    Write-Host 'Throwing'
}
Write-Host "$($count) key(s) removed"