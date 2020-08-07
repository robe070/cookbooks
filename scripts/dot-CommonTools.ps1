<#
.SYNOPSIS

Common tools

.EXAMPLE

#>

function Write-FormattedOutput
{
    [CmdletBinding()]
    Param(
         [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][Object] $Object,
         [Parameter(Mandatory=$False)][ConsoleColor] $BackgroundColor,
         [Parameter(Mandatory=$False)][ConsoleColor] $ForegroundColor
    )

    # save the current color
    $bc = $host.UI.RawUI.BackgroundColor
    $fc = $host.UI.RawUI.ForegroundColor

    # set the new color
    if($BackgroundColor -ne $null)
    {
       $host.UI.RawUI.BackgroundColor = $BackgroundColor
    }

    if($ForegroundColor -ne $null)
    {
        $host.UI.RawUI.ForegroundColor = $ForegroundColor
    }

    Write-Host $Object

    # restore the original color
    $host.UI.RawUI.BackgroundColor = $bc
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-RedOutput
{
    [CmdletBinding()]
    Param(
         [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][Object] $Object
    )

    Write-FormattedOutput $Object -ForegroundColor 'Red'
}

function Write-GreenOutput
{
    [CmdletBinding()]
    Param(
         [Parameter(Mandatory=$True,Position=1,ValueFromPipeline=$True,ValueFromPipelinebyPropertyName=$True)][Object] $Object
    )

    Write-FormattedOutput $Object -ForegroundColor 'Green'
}
function Log-Date
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

# Gets the current machine path and user path and makes it the current process path
function SyncRegistryPathToCurentProcess {
    $pathMachine = [System.Environment]::GetEnvironmentVariable('path', 'machine')
    $pathUser = [System.Environment]::GetEnvironmentVariable('path', 'user')
    [System.Environment]::SetEnvironmentVariable('path', $pathMachine + ';' + $pathUser ) | Write-Host
    $env:path | Write-Host
}

function Propagate-EnvironmentUpdate
{
    if (-not ("win32.nativemethods" -as [type])) {
        # import sendmessagetimeout from win32
        add-type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
   IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
   uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    }

    $HWND_BROADCAST = [intptr]0xffff;
    $WM_SETTINGCHANGE = 0x1a;
    $result = [uintptr]::zero

    # notify all windows of environment block change
    [win32.nativemethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE,
	    [uintptr]::Zero, "Environment", 2, 5000, [ref]$result);
}

<#
.SYNOPSIS

Add-DirectoryToEnvPathOnce
Add a directory to the path if it hasn't already been added

.DESCRIPTION

.EXAMPLE


#>
function Add-DirectoryToEnvPathOnce{
param (
    [string]
    $EnvVarToSet = 'PATH',

    [Parameter(Mandatory=$true)]
    [string]
    $Directory

    )

    $oldPath = [Environment]::GetEnvironmentVariable($EnvVarToSet, 'Machine')
    $match = '*' + $Directory + '*'
    $replace = $oldPath + ';' + $Directory
    Write-Debug "OldPath = $Oldpath" | Out-Host
    Write-Debug "match = $match" | Out-Host
    Write-Debug "replace = $replace" | Out-Host
    if ( $oldpath -notlike $match )
    {
        [Environment]::SetEnvironmentVariable($EnvVarToSet, $replace, 'Machine')
        Write-Debug "Machine $EnvVarToSet updated" | Out-Host
    }

    # System Path may be different to remote PS starting environment, so check it separately
    if ( $env:Path -notlike $match )
    {
        $env:Path += ';' + $Directory
        Write-Debug "local Path updated" | Out-Host
    }

    Propagate-EnvironmentUpdate
}

function Connect-RemoteSession
{
    # Wait until PSSession is available
    while ($true)
    {
        "$(Log-Date) Waiting for remote PS connection"
        $Script:session = New-PSSession $Script:publicDNS -Credential $creds -ErrorAction SilentlyContinue
        if ($null -ne $Script:session)
        {
            break
        }

        Sleep -Seconds 10
    }

    Write-Host "$(Log-Date) $Script:publicDNS remote PS connection obtained"
}

function Connect-RemoteSessionUri
{
    # Wait until PSSession is available
    while ($true)
    {
        "$(Log-Date) Waiting for remote PS connection"
        $Script:session = New-PSSession -ConnectionUri $uri -Credential $creds -ErrorAction SilentlyContinue
        if ($null -ne $Script:session)
        {
            break
        }

        Sleep -Seconds 10
    }

    Write-Host "$(Log-Date) $Script:publicDNS remote PS connection obtained"
}

function ReConnect-Session
{
    Write-Host "$(Log-Date) Reconnecting session..."
    if ( $Script:session ) { Remove-PSSession $Script:session | Out-Host }

    Connect-RemoteSession | Out-Host

    Execute-RemoteInit | Out-Host
    Execute-RemoteInitPostGit | Out-Host
}

function Reboot-Session
{
    # Execute Restart-Computer through remote session as executing from local machine is blocked
    Execute-RemoteBlock $Script:session {
        Restart-Computer -force
    }
    # Allow computer to stop before attempting a connection
    Start-Sleep -s 10

    ReConnect-Session
}

# Returns the button index for testing (Unless its Cancel in which case it throws an error)
# See https://docs.microsoft.com/en-us/previous-versions/windows/internet-explorer/ie-developer/windows-scripting/x83z1d9f(v=vs.84)
# for details
# $Buttons => 0 = OK, 1 = Ok/Cancel, 0x3 = Yes/No/Cancel, 0x4 = Yes/No
# Response => 2 = Cancel, 6 = Yes, 7 = No
function MessageBox
{
param (
    [Parameter(Mandatory=$true)]
    [string]
    $Message,
    [Parameter(Mandatory=$false)]
    [int]
    $buttons = 0x1,  # Ok/Cancel buttons
    [Parameter(Mandatory=$false)]
    [switch]
    $Pipeline
    )

    # OK and Cancel buttons
    Write-Host "$(Log-Date) $Message"

    if ($Pipeline) {
        Write-Host "$(Log-Date) Skipped the MessageBox for Pipeline"
        
        # Simulate OK button
        return 1
    }

    if ( -not $Script:msgbox ) {
        $Script:msgbox = New-Object -ComObject WScript.Shell
    }

    # Make a Sound, be System Modal
    $Response = $($Script:msgbox).popup( $Message, 0, $Script:DialogTitle, 0x30 + 0x1000 + $buttons)
    # 2 = Cancel
    if ( $Response -eq 2 )
    {
        Write-Host "$(Log-Date) $Script:DialogTitle cancelled"
        throw
    }

    return $Response
}

function Install-VisualLansa
{
    ######################################
    # The VL IDE silent install has some quirks.
    # 1. The VL IDE install will stop on the launch of VL if Integrator is installed. So, We install them separately
    #    That way the lengthy VL install can get to the end.
    # 2. Integrator install stops with the Close button needing to be clicked. Its a fast install so spawn it off
    #    and continue with other parts of the installation process.
    # 3. Users are NOT created now as they become invalid  once the system is sysprepped. LANSA Quick Config configures this.
    ######################################

    # Installation settings
    $SettingsFile = "$Script:ScriptTempPath\LansaSettings.txt"
    $SettingsPassword = 'lansa'
    $installer_file = "$Script:DvdDir\Setup\FileTransfer.exe"
    $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer').InstallSQLServer
    $InstanceName = "MSSQLSERVER"
    $Language = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Language').Language
    $LansaLanguage = '0';
    switch ($Language) {
        'ENG' { $LansaLanguage = '0'; }
        'FRA' { $LansaLanguage = '1'; }
        'JPN' { $LansaLanguage = '2'; }
        default { $LansaLanguage = '0'; }
    }

    if ( (Test-Path $SettingsFile) )
    {
        Remove-Item $SettingsFile
    }

    ##########################################
    # Visual LANSA Install
    ##########################################

"SetupType=1
NewInstallType=1
InstallLevel=2
RootDirectory=C:\Program Files (x86)\Lansa
AllowRootDirectoryChange=True
VisualLansaType=6
FeatureVL=1
FeatureVLCore=1
FeatureWeb=1
FeatureWebEditor=1
FeatureWebAdministrator=1
FeatureWebServer=1
FeatureIISPlugin=1
FeatureWebImages=1
FeatureIntegrator=1
FeatureJSM=1
FeatureJSMProxy=1
FeatureUserAgent=1
FeatureRFI=1
FeatureIntegratorStudio=1
FeatureOpen=1
FeatureOpenCore=1
FeatureOpenSamples=1
FeatureOpenTranslationTables=1
FeatureConnect=1
StartFolderName=LANSA
64bitVLSupport=False
DatabaseInstanceName=$InstanceName
DatabaseInstanceDirectory=C:\Program Files\Microsoft SQL Server
DatabaseDataDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSharedDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSAHidePassword=False
.DatabaseSAPassword=
DatabaseTCPIPWorkaround=
DatabaseName=LANSA
DatabaseDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.$InstanceName\MSSQL\Data
DatabaseLogDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.$InstanceName\MSSQL\Data
DSNNew=True
DSNName=LANSA
DSNType=2
DSNDriverType=17
DSNDriverName=ODBC Driver 13 for SQL Server" | Add-Content $SettingsFile

if ( $InstallSQLServer -eq $false ) {
"DatabaseAction=2
DatabaseNewInstance=False
DSNServerName=(local)" | Add-Content $SettingsFile
} else {
"DatabaseAction=3
DatabaseNewInstance=True
DSNServerName=127.0.0.1\$InstanceName" | Add-Content $SettingsFile
}

"DSNDatabaseName=LANSA
DSNUseTrustedConnections=True
DSNUserid=sa
.DSNPassword=112113200245048055164115207077090084060117130184210029036142038112134034166041252163025013128246
CompilerInstall=1
CompilerRootDirectory=C:\Program Files (x86)\LANSA\MicrosoftCompiler2013
CommonFileLocation=LRoute,L,,
HostRouteFileShared=False
HostRouteLUName=LANSA
HostRouteQualifier=localhost
HostRoutePortNumber=4545
HostRouteIpcOptions=1
ConnectToMaster=True
HostConnectIntegratedLogin=False
HostConnectUserid=pcxuser
.HostConnectPassword=
StopStartIIS=True
UseComputersName=True
NodeName=LANSA
InitializeDatabase=True
InitializePartitions=2
PartitionsToInitialize=DEX
SyncMaster=False
ImportExamplePartition=True
ImportExampleUserTask=False
ImportVLF=True
ImportDemo=True
RunDemo=False
ImportEnableForTheWeb=True
ImportClientDefinitions=True
InitializationLanguage=$Language
LansaLanguage=$LansaLanguage
InstallLanguage=$LansaLanguage
CCSID=1140
CustomCCSID=False
ClientToServerTranslationTable=ANSEBC1140
ServerToClientTranslationTable=EBC1140ANS
MessageFileName=DC@M01
HashCharacter=#
AtCharacter=@
DollarCharacter=$
LocalDataDirectory=C:\Program Files (x86)\LANSA\LANSA
ListenerAutomaticStartup=True
ListenerPortNumber=4545
UseridActionForVLWeb=0
UseridForVLWeb=PCXUSER2
.PasswordForVLWeb=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
NetworkClientPrepareAutoUpgrade=True
NetworkClientServerName=
NetworkClientServerRootDirectory=
NetworkClientServerMapping=
UseridActionForWebServer=2
UseridForWebServer=PCXUSER2
.PasswordForWebServer=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
VirtualDirectoryAlias=cgi-bin
VirtualDirectory=
AutostartJSMAdministratorService=True
IntegratorPortNumber=4560
IntegratorAdminPortNumber=4561
UseridActionForJSM=0
UseridForJSM=PCXUSER2
.PasswordForJSM=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
JavaVersionForIntegrator=1.8
OpenTranslationTableLansaProvided=1
OpenTranslationTable=1140
DatabaseSAPassword=sa+LANSA!" | Add-Content $SettingsFile

    [int]$VersionMajor = [int](Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'VersionMajor').VersionMajor

    if ( $VersionMajor -lt 14 ) {
        Add-Content $SettingsFile "DatabaseVersion=5"
    } else {
"DatabaseVersion=11
ListenerLRouteRecordName=LANSA
ListenerLRouteIpcOptions=3
Website=Default Web Site
WebsitePort=80
WebserverRecordDuplicate=False
WebserverRecordName=
WebserverRecordPort=0
WebServerHostRouteSystemName=LANSA
WebServerHostRouteHost=localhost
WebServerHostRoutePortNumber=4545
WebServerHostRouteIpcOptions=3
WebServerWindowsCredentials=False
DSNPort=0
CompilerType=0
CompilerSdkDirectory=" | Add-Content $SettingsFile
    }

    Write-Host ("Installing Visual LANSA")
    # Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait
    # Piping output to anywhere causes powershell to wait until the process completes execution
    if ( $VersionMajor -lt 14 ) {
        &$installer_file """$SettingsPassword""" """$SettingsFile""" | Out-Host
    } else {
        &$installer_file """$SettingsPassword""" """$SettingsFile""" """E""" | Out-Host
    }
}

function New-Shortcut {
<#
.SYNOPSIS
	Creates a new shortcut (.lnk file) pointing at the specified file.

.DESCRIPTION
	The New-Shortcut script creates a shortcut pointing at the target in the location you specify.  You may specify the location as a folder path (which must exist), with a name for the new file (ending in .lnk), or you may specify one of the "SpecialFolder" names like "QuickLaunch" or "CommonDesktop" followed by the name.
	If you specify the path for the link file without a .lnk extension, the path is assumed to be a folder.

.EXAMPLE
	New-Shortcut C:\Windows\Notepad.exe
		Will make a shortcut to notepad in the current folder named "Notepad.lnk"
.EXAMPLE
	New-Shortcut C:\Windows\Notepad.exe QuickLaunch\Editor.lnk -Description "Run Notepad"
		Will make a shortcut to notepad on the QuickLaunch bar with the name "Editor.lnk" and the tooltip "Run Notepad"
.EXAMPLE
	New-Shortcut C:\Windows\Notepad.exe F:\User\
		Will make a shortcut to notepad in the F:\User\ folder with the name "Notepad.lnk"
.NOTE
   Partial dependency on Get-SpecialPath ( http://poshcode.org/858 )
#>
[CmdletBinding()]
param(
   [Parameter(Position=0,Mandatory=$true)]
	[string]$TargetPath,
	## Put the shortcut where you want: "Special Folder" names allowed!
   [Parameter(Position=1,Mandatory=$true)]
	[string]$LinkPath,
	## Extra parameters for the shortcut
	[string]$Arguments="",
	[string]$WorkingDirectory="",
	[string]$WindowStyle="Normal",
	[string]$IconLocation="",
	[string]$Hotkey="",
	[string]$Description="",
	[string]$Folder=""
)

# Values for Window Style:
# 1 - Normal    -- Activates and displays a window. If the window is minimized or maximized, the system restores it to its original size and position.
# 3 - Maximized -- Activates the window and displays it as a maximized window.
# 7 - Minimized -- Minimizes the window and activates the next top-level window.

if(!(Test-Path $TargetPath) -and !($TargetPath.Contains("://"))) {
   Write-Error "TargetPath must be an existing file for the link to point at (or a URL)"
 	return
}

function New-ShortCutFile {
    param(
		[string]$TargetPath=$(throw "Please specify a TargetPath for link to point to"),
		[string]$LinkPath=$(throw "must pass a path for the shortcut file"),
		[string]$Arguments="",
		[string]$WorkingDirectory=$(Split-Path $TargetPath -parent),
		[string]$WindowStyle="Normal",
		[string]$IconLocation="",
		[string]$Hotkey="",
		[string]$Description=$(Split-Path $TargetPath -Leaf)
	)

	if(-not ($TargetPath.Contains("://") -or (Test-Path (Split-Path (Resolve-Path $TargetPath) -parent)))) {
		Throw "Cannot create Shortcut: Parent folder does not exist"
	}
	if(-not (Test-Path variable:\global:WshShell)) {
		$global:WshShell = New-Object -com "WScript.Shell"
	}


	$Link = $global:WshShell.CreateShortcut($LinkPath)
	$Link.TargetPath = $TargetPath

	[IO.FileInfo]$LinkInfo = $LinkPath

	## Properties for file shortcuts only
	## If the $LinkPath ends in .url you can't set the arguments, icon, etc
	## if you make the same shortcut with a .lnk extension
	## you can still point it at a URL, but you can set hotkeys, icons, etc
	if( $LinkInfo.Extension -ne ".url" ) {
		$Link.WorkingDirectory = $WorkingDirectory
		## Validate $WindowStyle
		if($WindowStyle -is [string]) {
			if( $WindowStyle -like "Normal" ) { $WindowStyle = 1 }
			if( $WindowStyle -like "Maximized" ) { $WindowStyle = 3 }
			if( $WindowStyle -like "Minimized" ) { $WindowStyle = 7 }
		}

		if( $WindowStyle -ne 1 -and $WindowStyle -ne 3 -and $WindowStyle -ne 7) { $WindowStyle = 1 }
		$Link.WindowStyle = $WindowStyle

		if($Hotkey.Length -gt 0 ) { $Link.HotKey = $Hotkey }
		if($Arguments.Length -gt 0 ) { $Link.Arguments = $Arguments }
		if($Description.Length -gt 0 ) { $Link.Description = $Description }
		if($IconLocation.Length -gt 0 ) { $Link.IconLocation = $IconLocation }

	}

  $Link.Save()
	Write-Host (get-item $LinkPath)
}


## If they didn't explicitly specify a folder
if($Folder.Length -eq 0) {
	if($LinkPath.Length -gt 0) {
		$path = Split-Path $LinkPath -parent
		[IO.FileInfo]$LinkInfo = $LinkPath
		if( $LinkInfo.Extension.Length -eq 0 ) {
			$Folder = $LinkPath
		} else {
			# If the LinkPath is just a single word with no \ or extension...
			if($path.Length -eq 0) {
				$Folder = $Pwd
			} else {
				$Folder = $path
			}
		}
	}
	else
	{ $Folder = $Pwd }
}

## If they specified a link path, check it for an extension
if($LinkPath.Length -gt 0) {
	$LinkPath = Split-Path $LinkPath -leaf
	[IO.FileInfo]$LinkInfo = $LinkPath
	if( $LinkInfo.Extension.Length -eq 0 ) {
		# If there's no extension, it must be a folder
		$Folder = $LinkPath
		$LinkPath = ""
	}
}
## If there's no Link name, make one up based on the target
if($LinkPath.Length -eq 0) {
	if($TargetPath.Contains("://")) {
		$LinkPath = "$($TargetPath.split('/')[2]).url"
	} else {
		[IO.FileInfo]$LinkInfo = $TargetPath
		$LinkPath = "$(([IO.FileInfo]$TargetPath).BaseName).lnk"
	}
}

## If the folder doesn't actually exist, maybe it's special...
if( -not (Test-Path $Folder)) {
	$morepath = "";
	if( $Folder.Contains("\") ) {
		$morepath = $Folder.SubString($Folder.IndexOf("\"))
		$Folder = $Folder.SubString(0,$Folder.IndexOf("\"))
	}
	$Folder = Join-Path (Get-SpecialPath $Folder) $morepath
	# or maybe they just screwed up
	trap { throw new-object ArgumentException "Cannot create shortcut: parent folder does not exist" }
}

$LinkPath = (Join-Path $Folder $LinkPath)
New-ShortCutFile $TargetPath $LinkPath $Arguments $WorkingDirectory $WindowStyle $IconLocation $Hotkey $Description
}

###############################################################################
## Get-SpecialPath Function (should be an external function in your profile, really)
##   This is an enhancement of [Environment]::GetFolderPath($folder) to add
##   support for 8 additional folders, including QuickLaunch, and the common
##   or "All Users" folders... while still supporting My Documents, Startup, etc.
##
function Get-SpecialPath
{
   param([string]$folder)
   BEGIN {
      if ($folder.Length -gt 0) {
         return $folder | &($MyInvocation.InvocationName);
      } else {
         $WshShellFolders=@{CommonDesktop=0;CommonStartMenu=1;CommonPrograms=2;CommonStartup=3;PrintHood=6;Fonts=8;NetHood=9};
      }
   }
   PROCESS {
      if($_){
         ## Eliminate the options that are easiest to eliminate
         if($_ -eq "QuickLaunch") {
            $f1 = [Environment]::GetFolderPath("ApplicationData")
            return Join-Path $f1 "\Microsoft\Internet Explorer\Quick Launch"
            ## Test WshShellFolders first because it's easiest won't throw an exception
         } elseif($WshShellFolders.Contains($_)){
            if(-not (Test-Path variable:\global:WshShell)) { $global:WshShell = New-Object -com "WScript.Shell" }
            return (([string[]]$global:WshShell.SpecialFolders) -split " ")[$WshShellFolders[$_]]
         } else {
            ## Finally, try GetFolderPath, and if it throws, change the error message:
            trap
            {
               throw new-object system.componentmodel.invalidenumargumentexception $(
                  "Cannot convert value `"$_`" to type `"SpecialFolder`" due to invalid enumeration values. " +
                  "Specify one of the following enumeration values and try again. The possible enumeration values are: " +
                  "Desktop, Programs, Personal, MyDocuments, Favorites, Startup, Recent, SendTo, StartMenu, MyMusic, " +
                  "DesktopDirectory, MyComputer, Templates, ApplicationData, LocalApplicationData, InternetCache, Cookies, " +
                  "History, CommonApplicationData, System, ProgramFiles, MyPictures, CommonProgramFiles, CommonDesktop, " +
                  "CommonStartMenu, CommonPrograms, CommonStartup, PrintHood, Fonts, NetHood, QuickLaunch")
            }
            return [Environment]::GetFolderPath($_)
         }
      }
   }
}

function Add-TrustedSite
{
param(
    [Parameter(Mandatory=$true)]
    [String]
    $SiteName,

    [Parameter(Mandatory=$false)]
    [String]
    $Hive="HKLM",

    [Parameter(Mandatory=$false)]
    [String]
    $urlType="http"
)
    $TrustedKey = "${Hive}:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\EscDomains\"
    $TrustedKeyPath = $TrustedKey + $SiteName
    New-Item "$TrustedKeyPath" -ErrorAction SilentlyContinue
    New-ItemProperty -Path "$TrustedKeyPath" -Name $urlType -Value 2 -PropertyType DWord -ErrorAction SilentlyContinue
}

function Disable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 0
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 0
    Write-Host "IE Enhanced Security Configuration (ESC) has been disabled." -ForegroundColor Green
}

function Enable-InternetExplorerESC {
    $AdminKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A7-37EF-4b3f-8CFC-4F3A74704073}"
    $UserKey = "HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components\{A509B1A8-37EF-4b3f-8CFC-4F3A74704073}"
    Set-ItemProperty -Path $AdminKey -Name "IsInstalled" -Value 1
    Set-ItemProperty -Path $UserKey -Name "IsInstalled" -Value 1
    Write-Host "IE Enhanced Security Configuration (ESC) has been enabled." -ForegroundColor Green
}

function Disable-UserAccessControl {
    Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "ConsentPromptBehaviorAdmin" -Value 00000000
    Write-Host "User Access Control (UAC) has been disabled." -ForegroundColor Green
}

# PlaySound will also play from an RDP session, unlike System.Media.SystemSounds
# Of course the RDP session needs to be configured to redirect sound to the local machine.
# This will play notify.wav 5 times
function PlaySound {
    $sound = new-Object System.Media.SoundPlayer;
    $sound.SoundLocation="c:\WINDOWS\Media\notify.wav";
    $sound.PlayLooping();
    $flag=$false;

    1..10 | foreach {
        if($_ -gt 5){$flag=$true} else{sleep -s 1}
        if($flag) { $sound.Stop() }
    }
}

function Run-ExitCode {
    param( [string]$Program, [String[]]$Arguments, [decimal]$ExitCodeException=0 )

    try {
        # Errors are handled specifically here so don't treat them as terminating errors (which these scripts do by default)

        $ErrorActionSaved = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'

        $ErrorFile = "$($ENV:TEMP)\error.txt"
        $OutFile = "$($ENV:TEMP)\out.txt"

        Remove-Item $OutFile -force -ErrorAction SilentlyContinue
        Remove-Item $ErrorFile -force -ErrorAction SilentlyContinue

        Write-GreenOutput( "$(Log-Date) Running $Program $([String]::Join(" ", $Arguments))." )
        $p = -1     # Set a value in case start-process throws an exception so we throw it cleanly after capturing whatever log messages there may be
        $p = Start-Process -FilePath $Program -ArgumentList $Arguments -Wait -PassThru -NoNewWindow -RedirectStandardError $ErrorFile -RedirectStandardOutput $OutFile
    } catch {
        $_
    } finally {
        $ErrorActionPreference = $ErrorActionSaved
        cat $OutFile -ErrorAction SilentlyContinue
        cat $ErrorFile -ErrorAction SilentlyContinue
        if ( $p -eq -1 ) {
            cmd /c exit -1
            $ErrorMessage = "$Program not found in path."

            throw $ErrorMessage
        } elseif ( $p.ExitCode -ne 0 -and ($p.ExitCode  -ne $ExitCodeException) ) {
            cmd /c exit $p.ExitCode
            $ErrorMessage = "$Program $([String]::Join(" ", $Arguments)) returned error code $($p.ExitCode)."

            throw $ErrorMessage
        }
    }
}

function Run-SSMCommand {
    param( [string] $instanceid, [string]$DocumentName, [Int32]$TimeoutSecond = 600, [string] $Comment, [HashTable] $Parameter, [Int32] $Sleep = 3 )

    $DebugPreference = "SilentlyContinue"

    $runPSCommand = Send-SSMCommand -InstanceId $instanceid -DocumentName $DocumentName -TimeoutSecond $TimeoutSecond -Comment $Comment -Parameter $Parameter
    Write-Host "$(Log-Date) Waiting for $Comment to complete..."
    do {
        Sleep -Seconds $Sleep
        $CmdStatus = Get-SSMCommandInvocation -InstanceId $instanceid -CommandId $runPSCommand.CommandId
    } while ($CmdStatus.Status -eq "Pending" -or $CmdStatus.Status -eq "InProgress")

    Write-Host "$(Log-Date) Command completed. Status"
    Out-Default -InputObject $CmdStatus.Status

    # Output the result
    $Output = Get-SSMCommandInvocation -CommandId $runPSCommand.CommandId -Details $true -InstanceId $instanceid | select -ExpandProperty CommandPlugins
    Out-Default -InputObject $output.Output

    $DebugPreference = "Continue"

    # Its expected that the Command will throw an error and thus the command will be flagged as 'failed'. Powershell scripts we run all throw when there is an error.
    if ( $CmdStatus.Status -eq "Failed" ) {
        cmd /c exit 1
        throw "Run-SSMCommand"
    }
}

function Get-CurrentLineNumber {
    $MyInvocation.ScriptLineNumber
}
function Get-CurrentFileName {
    $MyInvocation.ScriptName
}

function Test-RegKeyValueIsNotNull {
    param (
        [string]$RegKey
    )

    $RegKeyValue = Get-ItemProperty -Path HKLM:\Software\LANSA  -Name $RegKey
    if ( [ string ]::IsNullOrWhiteSpace($RegKeyValue.$RegKey) ) {
        throw "$RegKey is empty"
    } else {
        Write-Host( "$RegKey has value '$($RegKeyValue.$RegKey)'" )
    }
}

# Provide a common routine so its easily modified.
# Note that this is called to get the Plugin to reset. There may be other ways.
# iisreset without parameters caused issues as described below when a deployment
# through Git Deploy Hub had a new vl web runtime, necessitating an iisreset. Be aware
# that GDH is being run from IIS, so it gets terminated ... THIS routine's thread gets terminated ...
# but not before the iis /start has successfully completed.
# Prior issues:
# Using iisreset defaults to /stop /start /force.
# This frequently causes automatic kills to occur - Event Id 3204 in the system event log.
# What follows a 3204 is that other services may get killed too.
# occassionally iis is not restarted (last time there were 84 resets (42 iterations) before this occurred)
# New behavior:
# iisrest /stop /noforce changed the behaviour to 0 occurence of iis not starting in 1000 iterations,
# and returned 0 exit code every time. 5 x 3204 events still recorded in system event log, but that
# did not cause iis not to start and did not cause any dumps to be produced.
function Iis-Reset {
    Write-Host( "$(Log-Date) iisreset /stop /noforce..." )
    iisreset /stop /noforce
    if ( $LASTEXITCODE -ne 0 ) {
        Write-Host( "$(Log-Date) iisreset /stop /noforce resulted in exit code $LASTEXITCODE" )

        Write-Host( "$(Log-Date) iisreset /kill..." )
        iisreset /kill
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Host( "$(Log-Date) iisreset /kill resulted in exit code $LASTEXITCODE" )
            iisreset /kill

            Write-Host( "$(Log-Date) Pause 10s to allow IIS to 'recover'..." )
            Start-Sleep 10
        }
    }

    Write-Host( "$(Log-Date) iisreset /start..." )
    iisreset /start
    if ( $LASTEXITCODE -ne 0 ) {
        Write-Host( "$(Log-Date) iisreset /start resulted in exit code $LASTEXITCODE" )
        Write-Host( "$(Log-Date) iisreset /start again..." )
        iisreset /start
        if ( $LASTEXITCODE -ne 0 ) {
            Write-Host( "$(Log-Date) iisreset /start resulted in exit code $LASTEXITCODE" )
        }
    }
}