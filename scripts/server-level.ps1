$ServerGuiShell = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels'  -Name 'Server-Gui-Shell' -ErrorAction SilentlyContinue).'Server-Gui-Shell'
if ( -not $ServerGuiShell ) {
    $ServerCore = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels'  -Name 'ServerCore'  -ErrorAction SilentlyContinue).ServerCore
    if ( -not $ServerCore) {
        $NanoServer = (Get-ItemProperty -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Server\ServerLevels'  -Name 'NanoServer' -ErrorAction SilentlyContinue).NanoServer
        if ( -not $ServerCore) {
            Write-Error ("Unknown Server Level")
        } else {
            Write-Output ("Windows Nano Server")
        }
    } else {
        Write-Output ("Windows Server Core")
    }
} else {
    Write-Output ("Windows Full UI")
}
