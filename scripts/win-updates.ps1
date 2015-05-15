param($global:RestartRequired=0,
        $global:MoreUpdates=0,
        $global:MaxCycles=5,
        $MaxUpdatesPerCycle=500)

$Logfile = "C:\Windows\Temp\win-updates.log"

function LogWrite {
   Param ([string]$logstring)
   $now = Get-Date -format s
   Add-Content $Logfile -value "$now $logstring"
   Write-Output $logstring
}

function Check-ContinueRestartOrEnd() {
    $RegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
    $RegistryEntry = "InstallWindowsUpdates"
	switch ($global:RestartRequired) {
		0 {
			$prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
			if ($prop) {
				LogWrite "Restart Registry Entry Exists - Removing It"
				Remove-ItemProperty -Path $RegistryKey -Name $RegistryEntry -ErrorAction SilentlyContinue
			}

			LogWrite "No Restart Required"
			Check-WindowsUpdates

			if (($global:MoreUpdates -eq 1) -and ($script:Cycles -le $global:MaxCycles)) {
				Install-WindowsUpdates
			} elseif ($script:Cycles -gt $global:MaxCycles) {
				LogWrite "Exceeded Cycle Count - Stopping"
			} else {
				LogWrite "Done Installing Windows Updates"
			}
		}
		1 {
# AU - We don't want to run Windows update again. It seems "Run" doesn't automatically run after a login.
# We saw evidence of it running 20 minutes after a login and that wasn't even the first login after the
# instance was created.
<#
			$prop = (Get-ItemProperty $RegistryKey).$RegistryEntry
			if (-not $prop) {
				LogWrite "Restart Registry Entry Does Not Exist - Creating It"
				Set-ItemProperty -Path $RegistryKey -Name $RegistryEntry -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -File $($script:ScriptPath) -MaxUpdatesPerCycle $($MaxUpdatesPerCycle)"
			} else {
				LogWrite "Restart Registry Entry Exists Already"
			}
#>
			Logoff-Allusers

			LogWrite "Restart Required - Restarting..."
			Restart-Computer -force
		}
		default {
			LogWrite "Unsure If A Restart Is Required"
			break
		}
	}
}

function Install-WindowsUpdates() {
    $script:Cycles++
    LogWrite "Evaluating Available Updates with limit of $($MaxUpdatesPerCycle):"
    $UpdatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    $script:i = 0;
    $CurrentUpdates = @($SearchResult.Updates | Select-Object)
    while($script:i -lt $CurrentUpdates.Count -and $script:CycleUpdateCount -lt $MaxUpdatesPerCycle) {
        $Update = $CurrentUpdates[$script:i]
        if (($Update -ne $null) -and (!$Update.IsDownloaded)) {
            [bool]$addThisUpdate = $false
            if ($Update.InstallationBehavior.CanRequestUserInput) {
                LogWrite "> Skipping: $($Update.Title) because it requires user input"
            } else {
                if (!($Update.EulaAccepted)) {
                    LogWrite "> Note: $($Update.Title) has a license agreement that must be accepted. Accepting the license."
                    $Update.AcceptEula()
                    [bool]$addThisUpdate = $true
                    $script:CycleUpdateCount++
                } else {
                    [bool]$addThisUpdate = $true
                    $script:CycleUpdateCount++
                }
            }

            if ([bool]$addThisUpdate) {
                LogWrite "Adding: $($Update.Title)"
                $UpdatesToDownload.Add($Update) |Out-Null
            }
        }
        $script:i++
    }

    if ($UpdatesToDownload.Count -eq 0) {
        LogWrite "No Updates To Download..."
    } else {
        LogWrite 'Downloading Updates...'
        $ok = 0;
        while (! $ok) {
            try {
                $Downloader = $UpdateSession.CreateUpdateDownloader()
                $Downloader.Updates = $UpdatesToDownload
                $Downloader.Download()
                $ok = 1;
            } catch {
                LogWrite $_.Exception | Format-List -force
                LogWrite "Error downloading updates. Retrying in 30s."
                $script:attempts = $script:attempts + 1
                Start-Sleep -s 30
            }
        }
    }

    $UpdatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
    [bool]$rebootMayBeRequired = $false
    LogWrite 'The following updates are downloaded and ready to be installed:'
    foreach ($Update in $SearchResult.Updates) {
        if (($Update.IsDownloaded)) {
            LogWrite "> $($Update.Title)"
            $UpdatesToInstall.Add($Update) |Out-Null

            if ($Update.InstallationBehavior.RebootBehavior -gt 0){
                LogWrite "<<<< NEEDS REBOOT >>>>"
                [bool]$rebootMayBeRequired = $true
            }
        }
    }

    if ($UpdatesToInstall.Count -eq 0) {
        LogWrite 'No updates available to install...'
        $global:MoreUpdates=0
        $global:RestartRequired=0
        break
    }

    if ($rebootMayBeRequired) {
        LogWrite 'These updates may require a reboot'
        $global:RestartRequired=1
    }

    LogWrite 'Installing updates...'

    $Installer = $script:UpdateSession.CreateUpdateInstaller()
    $Installer.Updates = $UpdatesToInstall
    $InstallationResult = $Installer.Install()

    LogWrite "Installation Result: $($InstallationResult.ResultCode)"
    LogWrite "Reboot Required: $($InstallationResult.RebootRequired)"
    LogWrite 'Listing of updates installed and individual installation results:'
    if ($InstallationResult.RebootRequired) {
        $global:RestartRequired=1
    } else {
        $global:RestartRequired=0
    }

    for($i=0; $i -lt $UpdatesToInstall.Count; $i++) {
        New-Object -TypeName PSObject -Property @{
            Title = $UpdatesToInstall.Item($i).Title
            Result = $InstallationResult.GetUpdateResult($i).ResultCode
        }
    }

    Check-ContinueRestartOrEnd
}

function Check-WindowsUpdates() {
    LogWrite "Checking For Windows Updates"
    $Username = $env:USERDOMAIN + "\" + $env:USERNAME

	New-EventLog -Source $ScriptName -LogName 'Windows Powershell' -ErrorAction SilentlyContinue

	$Message = "Script: " + $ScriptPath + "`nScript User: " + $Username + "`nStarted: " + (Get-Date).toString()

	Write-EventLog -LogName 'Windows Powershell' -Source $ScriptName -EventID "104" -EntryType "Information" -Message $Message
	LogWrite $Message

	$script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
	$script:successful = $FALSE
	$script:attempts = 0
	$script:maxAttempts = 12
	while(-not $script:successful -and $script:attempts -lt $script:maxAttempts) {
		try {
			$script:SearchResult = $script:UpdateSearcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")
			$script:successful = $TRUE
		} catch {
			LogWrite $_.Exception | Format-List -force
			LogWrite "Search call to UpdateSearcher was unsuccessful. Retrying in 10s."
			$script:attempts = $script:attempts + 1
			Start-Sleep -s 10
		}
	}

	if ($SearchResult.Updates.Count -ne 0) {
		$Message = "There are " + $SearchResult.Updates.Count + " more updates."
		LogWrite $Message
		try {
			$script:SearchResult.Updates |Select-Object -Property Title, Description, SupportUrl, UninstallationNotes, RebootRequired, EulaAccepted |Format-List
			$global:MoreUpdates=1
		} catch {
			LogWrite $_.Exception | Format-List -force
			LogWrite "Showing SearchResult was unsuccessful. Rebooting."
			$global:RestartRequired=1
			$global:MoreUpdates=0
			Check-ContinueRestartOrEnd
			LogWrite "Should never see this text! Reboot should have already occurred"

			Logoff-Allusers

			LogWrite "Restart Required - Restarting..."
			Restart-Computer -Force
		}
	} else {
		LogWrite 'There are no applicable updates'
		$global:RestartRequired=0
		$global:MoreUpdates=0
	}

}

function Logoff-Allusers()
{
	# Force Logoff all RDP users so that reboot will work and applying updates less likely to fail 
	LogWrite 'Forcing logoff of all users'
	
	$win32OS = get-wmiobject win32_operatingsystem -computername $ENV:COMPUTERNAME
	$win32OS.psbase.Scope.Options.EnablePrivileges = $true
	$win32OS.win32shutdown(4)

	# Wait to make sure the users have actually been logged off
	# Not sure if this makes a difference
	Start-Sleep -s 10

	LogWrite 'Users have been logged off'
}

# Check registry for restarting flags
function CheckRestart([REF]$retval)
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

$script:ScriptName = $MyInvocation.MyCommand.ToString()
$script:ScriptPath = $MyInvocation.MyCommand.Path
$script:UpdateSession = New-Object -ComObject 'Microsoft.Update.Session'
$script:UpdateSession.ClientApplicationID = 'Packer Windows Update Installer'
$script:UpdateSearcher = $script:UpdateSession.CreateUpdateSearcher()
$script:SearchResult = New-Object -ComObject 'Microsoft.Update.UpdateColl'
$script:Cycles = 0
$script:CycleUpdateCount = 0

try
{
	Logoff-Allusers

	Check-WindowsUpdates
	if ($global:MoreUpdates -eq 1) {
		Install-WindowsUpdates
	} else {
		Check-ContinueRestartOrEnd
	}
}
catch
{
	$_
	LogWrite( $_ )
	LogWrite("Installation error: logoff failed? reboot failed?")
	exit 2
}


# Check for restart in case reboot not detected or a prior need for reboot has failed
# e.g. due to logged on users.
[bool]$restart = $false
CheckRestart( [REF]$restart)
if ( $restart )
{
	Logoff-Allusers

	LogWrite "Restart Required - Restarting..."
	Restart-Computer -Force
}
