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
# . "$script:IncludeDir\dot-wait-EC2State.ps1"
# . "$script:IncludeDir\dot-Create-EC2Instance"

try
{
    cmd /c schtasks /change /TN "\Microsoft\windows\application Experience\ProgramDataUpdater" /DISABLE

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Start-Process -FilePath $installer_file -Wait 

    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded"
    $ENV:PATH
    cd "$GitRepoPath\ChefCookbooks"
    chef-client -z -o "VLWebServer::MainRecipe"

    &"$script:IncludeDir\createLansaDevelopmentLicense.ps1" $TempPath

    CreateLicence "c:\\packerTemp\\LANSADevelopmentLicense.pfx" LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey"
    &"c:\lansa\scripts\installAwsSdk.ps1" $TempPath
    &"c:\lansa\scripts\scheduleTasks.ps1"
    &"c:\lansa\scripts\Get-StartupCmds.ps1"
    &"c:\lansa\scripts\windowsUpdatesSettings.ps1"
    &"c:\lansa\scripts\win-updates.ps1"
}
catch
{
    Write-Error ($_ | format-list | out-string)
    throw
}