<#
.SYNOPSIS

Install base LANSA requirements

.DESCRIPTION

This script calls a set of scripts to setup the base requirments of LANSA on a Windows Server.

It is intended to be run via remote PS on an AWS instance that has the LANSA Cookbooks git repository installed.

.EXAMPLE


#>
param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,

    [Parameter(Mandatory=$true)]
    [string]
    $TempPath,

    [Parameter(Mandatory=$true)]
    [string]
    $LicenseKeyPassword
    )

$DebugPreference = "Continue"
$VerbosePreference = "Continue"

$script:IncludeDir = "$GitRepoPath\scripts"

Write-Debug "script:IncludeDir = $script:IncludeDir"

# Includes
. "$Script:IncludeDir\dot-createlicense.ps1"
. "$Script:IncludeDir\dot-Add-DirectoryToEnvPathOnce.ps1"
. "$script:IncludeDir\dot-New-ErrorRecord.ps1"
. "$script:IncludeDir\dot-Get-AvailableExceptionsList.ps1"


try
{
    cmd /c schtasks /change /TN "\Microsoft\windows\application Experience\ProgramDataUpdater" /DISABLE

    Write-Output "$(Get-Date -format s) Installing Chef"
    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Start-Process -FilePath $installer_file -Wait 

    Write-Output "$(Get-Date -format s) Running Chef"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded"
    Write-Debug $ENV:PATH
    cd "$GitRepoPath\Cookbooks"
    chef-client -z -o VLWebServer::IDEBase
    if ( $LASTEXITCODE -ne 0 )
    {
        $errorRecord = New-ErrorRecord System.Configuration.Install.InstallException RecipeFailure `
            InvalidData $LASTEXITCODE -Message "Chef-Client exit code = $LASTEXITCODE."
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    # Installing SQL Server Powershell tools separate to Chef because ther is an error installing it 
    # when SQL 2014 is already installed, but it still works correctly with 2014.
    try
    {
        choco install SQL2012.Powershell
    }
    catch
    {
        # Ignore the expected errors
    }

    Write-Output "$(Get-Date -format s) Installing License"
    CreateLicence "$TempPath\LANSADevelopmentLicense.pfx" $LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey"

    Write-Output "$(Get-Date -format s) Installing AWS SDK"
    &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath

    Write-Output "$(Get-Date -format s) Running scheduleTasks.ps1"
    &"$Script:IncludeDir\scheduleTasks.ps1"
    
    Write-Output "$(Get-Date -format s) Running Get-StartupCmds.ps1"
    &"$Script:IncludeDir\Get-StartupCmds.ps1"

    cmd /c sc triggerinfo w32time start/networkon stop/networkoff
    cmd /c "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Ngen" executequeueditems
    cmd /c "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Ngen" executequeueditems
    &"$Script:IncludeDir\Ec2ConfigSettings.ps1" "c:\packerTemp\"

    if (0)
    {
        # Windows Updates cannot be run remotely using Remote PS. Note that ssh server CAN run it!
        Write-Output "$(Get-Date -format s) Running windowsUpdatesSettings.ps1"
        &"$Script:IncludeDir\windowsUpdatesSettings.ps1"
        Write-Output "$(Get-Date -format s) Running win-updates.ps1"
        &"$Script:IncludeDir\win-updates.ps1"
    }
}
catch
{
    Write-Error $(Get-Date -format s) ($_ | format-list | out-string)
    throw
}