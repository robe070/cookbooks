
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
    $LicenseKeyPassword,

    [Parameter(Mandatory=$true)]
    [string]
    $ChefRecipe
    )

Write-Debug "script:IncludeDir = $script:IncludeDir" | Out-Host

try
{
    if ( !(test-path $TempPath) ) {
        New-Item $TempPath -type directory -ErrorAction SilentlyContinue | Out-Host
    }

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer').InstallSQLServer
    
    Run-ExitCode 'schtasks' @( '/change', '/TN', '"\Microsoft\windows\application Experience\ProgramDataUpdater"', '/Disable' ) | Out-Host

    Write-Output "$(Log-Date) Installing Chef" | Out-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Run-ExitCode 'msiexec.exe' @( '/i', $installer_file, '/qn' ) | Out-Host

    Write-Output "$(Log-Date) Running Chef" | Out-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin" | Out-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded" | Out-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
    Write-Debug $ENV:PATH | Out-Host
    cd "$GitRepoPath\Cookbooks" | Out-Host
    
    chef-client -z -o $ChefRecipe | Out-Host
    if ( $LASTEXITCODE -ne 0 )
    {
        throw "Chef-Client exit code = $LASTEXITCODE."
    }
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
    
    # Make sure Git is in the path. Adding it in a prior script it gets 'lost' when Chef Zero is Run in this script
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd" | Out-Host
    Add-DirectoryToEnvPathOnce -Directory "C:\ProgramData\chocolatey\bin\" | Out-Host

    Write-Debug $ENV:PATH | Out-Host
    
    # Chrome had a packaging issue which temporarily required ignoring the checksum.
    # Re-instate it when next building an image
    Run-ExitCode 'choco' @( 'install', 'googlechrome', '-y', '--no-progress', '--ignorechecksum' ) | Out-Host
    Run-ExitCode 'choco' @( 'install', 'gitextensions', '-y', '--no-progress')  | Out-Host
    Run-ExitCode 'choco' @( 'install', 'jre8', '-y', '--no-progress' ) | Out-Host
    Run-ExitCode 'choco' @( 'install', 'kdiff3', '-y', '--no-progress' ) | Out-Host
    Run-ExitCode 'choco' @( 'install', 'vscode', '-y', '--no-progress' ) | Out-Host
    Run-ExitCode 'choco' @( 'install', 'sysinternals', '-y', '--no-progress' ) | Out-Host
    
    # Install Powershell 5.1. Needed for VS Code to debug Powershell scripts reliably and completely. 
    # Required for Windows Server 2012. What happens with 2016?
    # Requires a reboot to be fully installed. Presumed to be done by Windows Updates
    # Commented out because fails to install through this script - install it manually when needed
    # Run-ExitCode 'choco' @( 'install', 'powershell', '-y', '--no-progress' ) | Out-Host

    # the --% is so that the rest of the line can use simpler quoting
    # See this link for full help on passing msiexec params through choco: 
    # https://chocolatey.org/docs/commands-reference#how-to-pass-options-switches
    # This ensures that only English is installed as installing every language does not pass AWS virus checking
    Run-ExitCode 'choco' @( 'install', 'adobereader', '-y', '--no-progress', '--%', '-ia', 'LANG_LIST=en_US' )  | Out-Host

    # JRE often fails to download with a 404, so install it explicitly from AWS S3
    # ( Latest choco seems to have fixed this)
    # $jreurl = 'jre-8u172-windows-x64.exe'
    # $jretarget = 'jre-8u172-windows-x64.exe'
    # Run-ExitCode $jre @( '/s' ) | Out-Host

    New-Item $ENV:TEMP -type directory -ErrorAction SilentlyContinue | Out-Host
    
    if ( $Cloud -eq "AWS" ) {
        Write-Output "$(Log-Date) Installing AWS SDK" | Out-Host
        &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath | Out-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
        Propagate-EnvironmentUpdate | Out-Host
    
        Write-Output "$(Log-Date) Installing AWS CLI" | Out-Host
        &"$Script:IncludeDir\installAwsCli.ps1" $TempPath | Out-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host
        Add-DirectoryToEnvPathOnce -Directory "c:\Program Files\Amazon\AWSCLI" | Out-Host
        }

    if ( $Cloud -eq "Azure" ) {
        Write-Output "$(Log-Date) Installing AzCopy" | Out-Host
        &"$Script:IncludeDir\installAzCopy.ps1" $TempPath | Out-Host
    }

    Write-Output "$(Log-Date) Running scheduleTasks.ps1" | Out-Host
    &"$Script:IncludeDir\scheduleTasks.ps1" | Out-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Out-Host

    Write-Output "$(Log-Date) Running Get-StartupCmds.ps1" | Out-Host
    &"$Script:IncludeDir\Get-StartupCmds.ps1" | Out-Host

    Write-Output "$(Log-Date) Disable IE Enhanced Security Configuration so that Flash executes OK in LANSA eLearning" | Out-Host
    Disable-InternetExplorerESC | Out-Host
    
    if ( $Cloud -eq "AWS" ) {
        # Delete file which causes AWS to falsely detect that there is a virus
        # Conditioned on AWS as do not know the user name on Azure, and Azure does not complain. After all, its not a real virus!
        Remove-Item c:\Users\Administrator\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Out-Host
        Remove-Item c:\Users\Default\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Out-Host
    }

    if ( 0 )
    {
        # Windows Updates cannot be run remotely on AWS using Remote PS. Note that ssh server CAN run it!
        # On Azure it starts the check, but once it attempts the download of the updates it gets errors.
        Write-Output "$(Log-Date) Running windowsUpdatesSettings.ps1"
        &"$Script:IncludeDir\windowsUpdatesSettings.ps1"
        Write-Output "$(Log-Date) Running win-updates.ps1"
        &"$Script:IncludeDir\win-updates.ps1"
    }
}
catch
{
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Out-Host
    Write-RedOutput "install-lansa-base.ps1 is the <No file> in the stack dump below" | Out-Host
    throw
}

PlaySound

# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0