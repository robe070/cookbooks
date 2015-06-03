# Check registry for restarting flags
function Check-Restart([REF]$retval)
{
	$cn = $ENV:COMPUTERNAME
    [bool]$PendingFile = $false
    [bool]$AutoUpdate = $false

	#Determine PendingFileRenameOperations exists or not  
	$PendFileKeyPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\" 
	Invoke-Command -ComputerName $cn -ErrorAction SilentlyContinue -ScriptBlock{ 
	Get-ItemProperty -Path $using:PendFileKeyPath -name PendingFileRenameOperations} |` 
	Foreach{If($_.PendingFileRenameOperations){$PendingFile = $true}Else{$PendingFile = $false}} 
  
	#Determine RebootRequired subkey exists or not 
	$AutoUpdateKeyPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update" 
	Invoke-Command -ComputerName $cn -ErrorAction SilentlyContinue -ScriptBlock {Test-Path -Path "$using:AutoUpdateKeyPath\RebootRequired"} |` 
	Foreach{If($_ -eq $true){$AutoUpdate = $true}Else{$AutoUpdate = $false}} 

	$retval.Value = ($AutoUpdate -or $PendingFile)
}