function Write-Log {
PARAM
(
[Parameter(Mandatory = $true)] [string] $logMessage
, [ValidateSet("Green", "Yellow", "Red")] [string] $Color
)
$Datestamp = [datetime]::Now.ToString("yyyy-MM-dd HH:mm:ss.fff")
$FullMessage = "$Datestamp $logMessage"
if ($Color) {
Write-Host $FullMessage -ForegroundColor $Color
}
else {
Write-Host $FullMessage
}
$FullMessage | out-file -encoding ASCII $LogFilePath -Append
}
function Enable-OfflineDisk {
# Ensure this function runs in en-US culture"
# NOTE: This will fail if en-US is not available on the target server
chcp 437 | Out-Null
$offlinedisk = "rescan`nlist disk" | diskpart | Where-Object { $_ -match "offline" }
if ($offlinedisk) {
Write-Host "Following Offline disk(s) found..Trying to bring Online."
foreach ($offdisk in $offlinedisk) {
$offdiskS = $offdisk.Substring(2, 6)
Write-Host "Enabling $offdiskS"
$OnlineDisk = @"
select $offdiskS
attributes disk clear readonly
online disk
attributes disk clear readonly
"@
$noOut = $OnlineDisk | diskpart
Start-Sleep 5
}
if ($culture.Name -eq "ja-JP") {
$offlinedisk = "list disk" | diskpart | Where-Object { $_ -match "オフライン" }
}
else {
$offlinedisk = "list disk" | diskpart | Where-Object { $_ -match "offline" }
}
if ($offlinedisk)
{
Write-Host "Failed to bring the following disk(s) online"
$offlinedisk
Exit 1
}
else {
Write-Host "Disk(s) are now online."
}
}
else {
Write-Host "All disk(s) are online!"
}
}
function Find-WindowSetupPath {
Enable-OfflineDisk
$CurrentDrives = ([System.IO.DriveInfo]::getdrives() | select-object -ExpandProperty Name) -join ','
Write-host "Current drives are $CurrentDrives"
$OldDrives = Get-Content -Path "C:\WindowsUpgrade\{{ automation:EXECUTION_ID }}\drive.txt" -TotalCount 1
$oldDriveArray = $OldDrives.split(',')
$newDriveArray = $CurrentDrives.split(',')
foreach ($drive in $newDriveArray) {
if (-not ($oldDriveArray -contains $drive)) {
$NewDrive = $drive
break
}
}
if (-not $NewDrive) {
Write-Log "Can't find the new drive"
exit -1
}
$SetupLocation = "$NewDrive\setup.exe"
if ((Test-Path $SetupLocation) -eq $false) {
$isomount = $(Mount-DiskImage -ImagePath "$NewDrive$(Get-Childitem -Path $NewDrive -Include *.ISO -Recurse | Select-Object Name -ExpandProperty Name)" -PassThru | Get-DiskImage | Get-Volume).DriveLetter
$SetupLocation = "{0}:\setup.exe" -f $isomount
Write-Host "Found ISO in the installation media $NewDrive . ISO Mounted as"$isomount":\ ."
}
Write-host "Olddrives $OldDrives , Currentdrives $CurrentDrives, Newdrive $NewDrive, Setup location is $SetupLocation "
if ((Test-Path $SetupLocation) -eq $false) {
Write-Log "Error: Couldn't find Windows Server {{ TargetWindowVersion }} installation media snapshot. Please contact AWS Premium Support." "Red"
exit -1
}
Return $SetupLocation
}
function Upgrade-Server {
$marker = "$UpgradeDirectory\upgrade_success.marker"
if (Test-Path $marker) {
Write-Log "Marker found: post-reboot execution. Running post-reboot validation..." "Yellow"
} else {
sc.exe config AmazonSSMAgent start= delayed-auto
Start-sleep -s 5
$osInfo = (Get-WmiObject -class Win32_OperatingSystem)
$OSVersion = $osInfo.Caption.ToUpper()
if ($OSVersion.indexOf("DATACENTER") -ge 0) { $version = 4 } else { $version = 2 }
$TargetVersion = "{{ TargetWindowVersion }}"
Write-Log "Current OS version: $OSVersion. Target OS version: $TargetVersion. Using image index $version for upgrade." "Yellow"
$arguments = "/auto upgrade /imageindex $version /compat ignorewarning /showoobe none /DynamicUpdate Disable /noreboot /AcceptEula"
Write-Log "Starting Windows Setup at $UpgradeSetUpPath with arguments: $arguments" "Yellow"
$process = Start-Process -FilePath $UpgradeSetUpPath -ArgumentList $arguments -Wait -PassThru
Write-Log "Starting Windows Setup at $UpgradeSetUpPath with arguments: $arguments" "Yellow"
$process = Start-Process -FilePath $UpgradeSetUpPath -ArgumentList $arguments -Wait -PassThru
$exitCode = $process.ExitCode
Write-Log "Setup.exe exited with code $exitCode" "Yellow"
if ($exitCode -eq 0 -or $exitCode -eq 3010) {
Write-Log "Setup completed successfully (exit code $exitCode). Creating marker and rebooting..." "Green"
New-Item -ItemType File -Path $marker -Force | Out-Null
Restart-Computer -Force
exit 3010
} else {
Write-Log "Setup failed with exit code $exitCode" "Red"
exit 1
}
}
if (Test-Path $marker) {
Write-Log "Post-reboot validation: upgrade marker exists. Upgrade succeeded." "Green"
} else {
Write-Log "Post-reboot validation failed: marker missing. Upgrade did not complete successfully." "Red"
exit 1
}
}
$UpgradeDirectory = "C:\WindowsUpgrade\{{ automation:EXECUTION_ID }}"
$Global:LogFilePath = $UpgradeDirectory + "\Logfile.txt"
$UpgradeSetUpPath = Find-WindowSetupPath
Upgrade-Server