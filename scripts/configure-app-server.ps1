# 
"configure-app-server.ps1"
For ( $i = 1; $i -le 10; $i++) {
    Write-Output("")
    $regkeyfolder = "HKLM:\Software\LANSA\C:%5CPROGRAM%20FILES%20(X86)%5CAPP$($i)\LANSAWEB"
    $regkeyname = "FREESLOTS"
    Write-Output("Setting $RegKeyFolder $RegKeyName Ready To Use Minimum to 20")
    New-ItemProperty -Path $regkeyfolder  -Name $regkeyname -Value '20' -PropertyType String -Force  | Out-Null

    $regkeyname = "REUSE"
    Write-Output("Setting $RegKeyFolder $RegKeyName To Maximum")
    New-ItemProperty -Path $regkeyfolder  -Name $regkeyname -Value '0' -PropertyType String -Force  | Out-Null

    $regkeyname = "MAXFREE"
    Write-Output("Setting $RegKeyFolder $RegKeyName Ready To Use Maximum to 9999")
    New-ItemProperty -Path $regkeyfolder  -Name $regkeyname -Value '9999' -PropertyType String -Force  | Out-Null
}