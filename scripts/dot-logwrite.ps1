$Script:Logfile = "C:\Windows\Temp\win-updates.log"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Scipt:Logfile -value "$now $logstring"
   Write-Output $logstring
}
