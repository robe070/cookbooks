
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

Write-Debug "script:IncludeDir = $script:IncludeDir"

try
{
    if ( !(test-path $TempPath) ) {
        # The successful creation of this directory causes the previous output to be seen on the calling console
        New-Item $TempPath -type directory -ErrorAction SilentlyContinue
    }

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer').InstallSQLServer
    
    Run-ExitCode 'schtasks' @( '/change', '/TN', '"\Microsoft\windows\application Experience\ProgramDataUpdater"', '/Disable' )

    Write-Output "$(Log-Date) Installing Chef"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Run-ExitCode 'msiexec.exe' @( '/i', $installer_file, '/qn' )

    Write-Output "$(Log-Date) Running Chef"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Write-Debug $ENV:PATH
    cd "$GitRepoPath\Cookbooks"
    
    chef-client -z -o $ChefRecipe
    if ( $LASTEXITCODE -ne 0 )
    {
        $errorRecord = New-ErrorRecord System.Configuration.Install.InstallException RecipeFailure `
            InvalidData $LASTEXITCODE -Message "Chef-Client exit code = $LASTEXITCODE."
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    
    # Make sure Git is in the path. Adding it in a prior script it gets 'lost' when Chef Zero is Run in this script
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd"

    Run-ExitCode 'choco' @( 'install', 'gitextensions', '--version', '2.49', '-y')
    Run-ExitCode 'choco' @( 'install', 'jre8', '-y' )
    Run-ExitCode 'choco' @( 'install', 'kdiff3', '-y' )
    Run-ExitCode 'choco' @( 'install', 'adobereader', '-y' )
    New-Item $ENV:TEMP -type directory -ErrorAction SilentlyContinue
    
    if ( $Cloud -eq "AWS" ) {
        Write-Output "$(Log-Date) Installing AWS SDK"
        &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
        Propagate-EnvironmentUpdate
    
        Write-Output "$(Log-Date) Installing AWS CLI"
        &"$Script:IncludeDir\installAwsCli.ps1" $TempPath
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
        Add-DirectoryToEnvPathOnce -Directory "c:\Program Files\Amazon\AWSCLI"
        }

    if ( $Cloud -eq "Azure" ) {
        Write-Output "$(Log-Date) Installing AzCopy"
        &"$Script:IncludeDir\installAzCopy.ps1" $TempPath
    }

    Write-Output "$(Log-Date) Running scheduleTasks.ps1"
    &"$Script:IncludeDir\scheduleTasks.ps1"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    Write-Output "$(Log-Date) Running Get-StartupCmds.ps1"
    &"$Script:IncludeDir\Get-StartupCmds.ps1"

    Write-Output "$(Log-Date) Disable IE Enhanced Security Configuration so that Flash executes OK in LANSA eLearning"
    Disable-InternetExplorerESC

    if ( $Cloud -eq "AWS" ) {
        # Delete file which causes AWS to falsely detect that there is a virus
        # Conditioned on AWS as do not know the user name on Azure, and Azure does not complain. After all, its not a real virus!
        Remove-Item c:\Users\Administrator\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue
        Remove-Item c:\Users\Default\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue
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
    Write-Error $(Log-Date) ($_ | format-list | out-string)
    throw
}

PlaySound

# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0