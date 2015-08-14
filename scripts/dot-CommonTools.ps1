<#
.SYNOPSIS

Common tools

.EXAMPLE

#>

function Log-Date 
{
    ((get-date).ToUniversalTime()).ToString("yyyy-MM-dd HH:mm:ssZ")
}

function Connect-RemoteSession
{
    # Wait until PSSession is available
    while ($true)
    {
        "$(Log-Date) Waiting for remote PS connection"
        $Script:session = New-PSSession $Script:publicDNS -Credential $creds -ErrorAction SilentlyContinue
        if ($Script:session -ne $null)
        {
            break
        }

        Sleep -Seconds 10
    }

    Write-Output "$(Log-Date) $Script:instanceid remote PS connection obtained"
}

function MessageBox
{
param (
    [Parameter(Mandatory=$true)]
    [string]
    $Message
    )

    # OK and Cancel buttons
    Write-Output "$(Log-Date) $Message"
    $Response = [System.Windows.Forms.MessageBox]::Show("$Message", $Script:DialogTitle, 1 ) 
    if ( $Response -eq "Cancel" )
    {
        Write-Output "$(Log-Date) $Script:DialogTitle cancelled"
        throw
    }
}

function Install-VisualLansa
{
    ######################################
    # The VL IDE silent install has some quirks.
    # 1. The VL IDE install will stop on the launch of VL if Integrator is installed. So, We install them separately
    #    That way the lengthy VL install can get to the end.
    # 2. Integrator install stops with the Close button needing to be clicked. Its a fast install so spawn it off
    #    and continue with other parts of the installation process.
    ######################################

    # Installation settings
    $SettingsFile = "$Script:ScriptTempPath\LansaSettings.txt"
    $SettingsPassword = 'lansa'
    $installer_file = "$Script:DvdDir\Setup\FileTransfer.exe"

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
FeatureIntegrator=0
FeatureJSM=0
FeatureJSMProxy=0
FeatureUserAgent=0
FeatureRFI=0
FeatureIntegratorStudio=0
FeatureOpen=1
FeatureOpenCore=1
FeatureOpenSamples=1
FeatureOpenTranslationTables=1
FeatureConnect=1
StartFolderName=LANSA
64bitVLSupport=False
DatabaseAction=2
DatabaseNewInstance=False
DatabaseInstanceName=
DatabaseInstanceDirectory=C:\Program Files\Microsoft SQL Server
DatabaseDataDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSharedDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSAHidePassword=False
.DatabaseSAPassword=
DatabaseVersion=0
DatabaseTCPIPWorkaround=
DatabaseName=LANSA
DatabaseDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Data
DatabaseLogDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Data
DSNNew=True
DSNName=LANSA
DSNType=2
DSNDriverType=10
DSNDriverName=SQL Server Native Client 11.0
DSNServerName=$env:COMPUTERNAME
DSNDatabaseName=LANSA
DSNUseTrustedConnections=True
DSNUserid=sa
.DSNPassword=112113200245048055164115207077090084060117130184210029036142038112134034166041252163025013128246
CompilerInstall=1
CompilerRootDirectory=C:\Program Files (x86)\LANSA\MicrosoftCompiler2010
HostRouteLUName=*LOCAL
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
InitializePartitions=1
PartitionsToInitialize=DEX
SyncMaster=False
ImportExamplePartition=True
ImportExampleUserTask=False
ImportVLF=True
ImportDemo=True
RunDemo=False
ImportEnableForTheWeb=True
ImportClientDefinitions=True
InitializationLanguage=ENG
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
UseridActionForVLWeb=1
UseridForVLWeb=PCXUSER2
.PasswordForVLWeb=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
NetworkClientPrepareAutoUpgrade=True
NetworkClientServerName=
NetworkClientServerRootDirectory=
NetworkClientServerMapping=
UseridActionForWebServer=2
UseridForWebServer=PCXUSER2
.PasswordForWebServer=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
WebsiteIISPlugin=016Default Web Site
WebsiteWebImages=Default Web Site
WebsiteJSM=Default Web Site
VirtualDirectoryAlias=cgi-bin
VirtualDirectory=
AutostartJSMAdministratorService=True
IntegratorPortNumber=4560
IntegratorAdminPortNumber=4561
UseridActionForJSM=2
UseridForJSM=PCXUSER2
.PasswordForJSM=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053 
JavaVersionForIntegrator=
OpenTranslationTableLansaProvided=1
OpenTranslationTable=1140
LansaLanguage=0
InstallLanguage=0
DatabaseSAPassword=sa+LANSA!" | out-file $SettingsFile

    Write-Output ("Installing Visual LANSA")
    # Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait
    # Piping output to anywhere causes powershell to wait until the process completes execution
    &$installer_file """$SettingsPassword""" """$SettingsFile""" | Write-Output
}

function Install-Integrator
{
    ##########################################
    # Integrator Install
    ##########################################

    $SettingsFile = "$Script:ScriptTempPath\IntegratorSettings.txt"
    $SettingsPassword = 'lansa'
    $installer_file = "$Script:DvdDir\Setup\FileTransfer.exe"

"SetupType=1
NewInstallType=1
InstallLevel=2
RootDirectory=C:\Program Files (x86)\LANSA
AllowRootDirectoryChange=True
VisualLansaType=6
FeatureVL=0
FeatureVLCore=0
FeatureWeb=0
FeatureWebEditor=0
FeatureWebAdministrator=0
FeatureWebServer=0
FeatureIISPlugin=0
FeatureWebImages=0
FeatureIntegrator=1
FeatureJSM=1
FeatureJSMProxy=1
FeatureUserAgent=1
FeatureRFI=1
FeatureIntegratorStudio=1
FeatureOpen=0
FeatureOpenCore=0
FeatureOpenSamples=0
FeatureOpenTranslationTables=0
FeatureConnect=0
StartFolderName=LANSA
64bitVLSupport=False
DatabaseAction=2
DatabaseNewInstance=False
DatabaseInstanceName=
DatabaseInstanceDirectory=C:\Program Files\Microsoft SQL Server
DatabaseDataDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSharedDirectory=C:\Program Files\Microsoft SQL Server
DatabaseSAHidePassword=False
.DatabaseSAPassword=
DatabaseVersion=0
DatabaseTCPIPWorkaround=
DatabaseName=LANSA
DatabaseDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Data
DatabaseLogDirectory=C:\Program Files\Microsoft SQL Server\MSSQL12.MSSQLSERVER\MSSQL\Data
DSNNew=True
DSNName=LANSA
DSNType=2
DSNDriverType=10
DSNDriverName=SQL Server Native Client 11.0
DSNServerName=WIN-30TDV82PPMH
DSNDatabaseName=LANSA
DSNUseTrustedConnections=True
DSNUserid=sa
.DSNPassword=112113200245048055164115207077090084060117130184210029036142038112134034166041252163025013128246
CompilerInstall=1
CompilerRootDirectory=C:\Program Files (x86)\LANSA\MicrosoftCompiler2010
HostRouteLUName=*LOCAL
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
InitializePartitions=1
PartitionsToInitialize=DEX
SyncMaster=False
ImportExamplePartition=True
ImportExampleUserTask=False
ImportVLF=True
ImportDemo=True
RunDemo=False
ImportEnableForTheWeb=True
ImportClientDefinitions=True
InitializationLanguage=ENG
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
UseridActionForVLWeb=1
UseridForVLWeb=PCXUSER2
.PasswordForVLWeb=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
NetworkClientPrepareAutoUpgrade=True
NetworkClientServerName=
NetworkClientServerRootDirectory=
NetworkClientServerMapping=
UseridActionForWebServer=2
UseridForWebServer=PCXUSER2
.PasswordForWebServer=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053
WebsiteIISPlugin=016Default Web Site
WebsiteWebImages=Default Web Site
WebsiteJSM=Default Web Site
VirtualDirectoryAlias=cgi-bin
VirtualDirectory=
AutostartJSMAdministratorService=True
IntegratorPortNumber=4560
IntegratorAdminPortNumber=4561
UseridActionForJSM=2
UseridForJSM=PCXUSER2
.PasswordForJSM=161106219029123027150220095009114001171004042063034006087198091041059125101248041226025151149053 
JavaVersionForIntegrator=
OpenTranslationTableLansaProvided=1
OpenTranslationTable=1140
LansaLanguage=0
InstallLanguage=0
DatabaseSAPassword=sa+LANSA!"| out-file $SettingsFile

    Write-Output ("Installing Integrator")
    # Start-Process -FilePath $installer_file -ArgumentList $Arguments -Wait
    # output NOT PIPED to anywhere so powershell DOES NOT wait until the process completes execution
    &$installer_file """$SettingsPassword""" """$SettingsFile"""
}