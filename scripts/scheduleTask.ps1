$action = New-ScheduledTaskAction -Execute '%windir%\system32\w32tm.exe' -Argument '/resync'
$trigger1 =   New-ScheduledTaskTrigger -Daily -At 1:15am
$trigger2 =   New-ScheduledTaskTrigger -AtStartup
Register-ScheduledTask -Action $action -Trigger $trigger1, $trigger2 -TaskName "Sync Time daily" -RunLevel Highest -user LocalService -TaskPath "\Microsoft\Windows\Time Synchronization"
