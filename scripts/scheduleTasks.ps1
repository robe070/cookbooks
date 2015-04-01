$action = New-ScheduledTaskAction -Execute '%windir%\system32\w32tm.exe' -Argument '/resync'
$trigger1 =   New-ScheduledTaskTrigger -Daily -At 1:15am
$trigger2 =   New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger1, $trigger2 -TaskName "Sync Time daily" -RunLevel Highest -user LocalService -TaskPath "\Microsoft\Windows\Time Synchronization"

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy unrestricted -file C:\recipes\Get-StartupCmds.ps1'
$trigger1 =    New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger1 -TaskName "Log Startup Commands"-RunLevel Highest -user System -TaskPath "\"
 
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument '/c "del c:\windows\temp\startup.log"'
$trigger1 =    New-ScheduledTaskTrigger -Weekly -At 1:17am -DaysOfWeek Sunday
Register-ScheduledTask -Action $action -Trigger $trigger1 -TaskName "Delete Startup Log" -RunLevel Highest -user System -TaskPath "\"
