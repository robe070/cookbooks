# Check registry for restarting flags
function Check-Restart([REF]$retval)
{
    [bool]$PendingFile = $false
    [bool]$AutoUpdate = $false

	#Determine PendingFileRenameOperations exists or not  
	$PendFileKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\" 
	Get-ItemProperty -Path $PendFileKeyPath -name PendingFileRenameOperations -ErrorAction SilentlyContinue |` 
	Foreach{If($_.PendingFileRenameOperations){$PendingFile = $true}} 
  
	#Determine RebootRequired subkey exists or not 
	$AutoUpdateKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" 
	Test-Path -Path "$AutoUpdateKeyPath\RebootRequired" | Foreach { If($_ -eq $true){$AutoUpdate = $true}} 

    Write-Output "AutoUpdate   = $AutoUpdate"
    Write-Output "PendingFile  = $PendingFile"
	$retval.Value = ($AutoUpdate -or $PendingFile)
}