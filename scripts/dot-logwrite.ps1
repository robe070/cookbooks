$Script:Logfile = "C:\Windows\Temp\win-updates.log"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Script:Logfile -value "$now $logstring"
   Write-Output $logstring
}
