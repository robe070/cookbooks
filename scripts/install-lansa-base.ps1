
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

Write-Debug "script:IncludeDir = $script:IncludeDir" | Write-Host

try
{
    if ( !(test-path $TempPath) ) {
        New-Item $TempPath -type directory -ErrorAction SilentlyContinue | Write-Host
    }

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer').InstallSQLServer

    Run-ExitCode 'schtasks' @( '/change', '/TN', '"\Microsoft\windows\application Experience\ProgramDataUpdater"', '/Disable' ) | Write-Host

    Write-GreenOutput "$(Log-Date) Installing Chef" | Write-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Run-ExitCode 'msiexec.exe' @( '/i', $installer_file, '/qn' ) | Write-Host

    Write-GreenOutput "$(Log-Date) Running Chef" | Write-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin" | Write-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded" | Write-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
    Write-Debug $ENV:PATH | Write-Host
    cd "$GitRepoPath\Cookbooks" | Write-Host

    chef-client -z -o $ChefRecipe | Write-Host
    if ( $LASTEXITCODE -ne 0 )
    {
        throw "Chef-Client exit code = $LASTEXITCODE."
    }
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

    # Make sure Git is in the path. Adding it in a prior script it gets 'lost' when Chef Zero is Run in this script
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd" | Write-Host
    Add-DirectoryToEnvPathOnce -Directory "C:\ProgramData\chocolatey\bin\" | Write-Host

    Write-Debug $ENV:PATH | Write-Host

    if ( $Cloud -eq "AWS" ) {
        Write-GreenOutput("$(Log-Date) Installing CloudWatch Agent") | Write-Host

        $CWASetup = 'https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/AmazonCloudWatchAgent.zip'
        $installer_file = ( Join-Path -Path $env:temp -ChildPath 'AmazonCloudWatchAgent.zip' )
        Write-Host ("$(Log-Date) Downloading $CWASetup to $installer_file")
        $downloaded = $false
        $TotalFailedDownloadAttempts = 0
        $TotalFailedDownloadAttempts = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -ErrorAction SilentlyContinue).TotalFailedDownloadAttempts
        $loops = 0
        while (-not $Downloaded -and ($Loops -le 10) ) {
            try {
                (New-Object System.Net.WebClient).DownloadFile($CWASetup, $installer_file) | Write-Host
                $downloaded = $true
            } catch {
                $TotalFailedDownloadAttempts += 1
                New-ItemProperty -Path HKLM:\Software\LANSA  -Name 'TotalFailedDownloadAttempts' -Value ($TotalFailedDownloadAttempts) -PropertyType DWORD -Force | Out-Null
                $loops += 1

                Write-Host ("$(Log-Date) Total Failed Download Attempts = $TotalFailedDownloadAttempts")

                if ($loops -gt 10) {
                    throw "Failed to download $CWASetup from S3"
                }

                # Pause for 30 seconds. Maybe that will help it work?
                Start-Sleep 30
            }
        }

        $InstallerDirectory = ( Join-Path -Path $env:temp -ChildPath 'AmazonCloudWatchAgent' )
        New-Item $InstallerDirectory -ItemType directory -Force

        # Expand-Archive $installer_file -DestinationPath $InstallerDirectory -Force | Write-Host

        Write-GreenOutput( "$(Log-Date) Unzipping $installer_file to $InstallerDirectory") | Write-Host
        $filePath = $installer_file
        $shell = New-Object -ComObject Shell.Application
        $zipFile = $shell.NameSpace($filePath)
        $destinationFolder = $shell.NameSpace($InstallerDirectory)

        $copyFlags = 0x00
        $copyFlags += 0x04 # Hide progress dialogs
        $copyFlags += 0x10 # Overwrite existing files

        $destinationFolder.CopyHere($zipFile.Items(), $copyFlags)

        # Installer file MUST be executed with the current directory set to the installer directory
        $InstallerScript = '.\install.ps1'
        Set-Location $InstallerDirectory | Write-Host
        & $InstallerScript | Write-Host

        # Start CloudWatchAgent so that the service gets installed, so that it can be stopped and set to manual!!
        # CF template then configures it but does not start it. Its intended to only be enabled through Systems Manager
        .\amazon-cloudwatch-agent-ctl.ps1 -a start -s

        Write-Host( "$(Log-Date) Set Cloud Watch Agent Service to manual")
        set-service -Name AmazonCloudWatchAgent -StartupType Manual | Write-Host
        stop-service -Name AmazonCloudWatchAgent | Write-Host
        get-service AmazonCloudWatchAgent | SELECT-OBJECT Name, StartType, Status | Write-Host
    }

    Run-ExitCode 'choco' @( 'install', 'googlechrome', '-y', '--no-progress' ) | Write-Host
    Run-ExitCode 'choco' @( 'install', 'gitextensions', '-y', '--no-progress', '--version 2.51.5')  | Write-Host # v3.2 fails to install gitextensions. v3.1.1 fails to install a Windows Update on Win 2012
    Run-ExitCode 'choco' @( 'install', 'jre8', '-y', '--no-progress', '-PackageParameters "/exclude:32"' ) | Write-Host
    Run-ExitCode 'choco' @( 'install', 'kdiff3', '-y', '--no-progress' ) | Write-Host
    Run-ExitCode 'choco' @( 'install', 'vscode', '-y', '--no-progress' ) | Write-Host
    try {
        # Don't install sysinternals because the license expressly forbids installing it on hosting services
        # Run-ExitCode 'choco' @( 'install', 'sysinternals', '-y', '--no-progress' ) | Write-Host
    } catch {
        # This was temporary and left in as an example of working around hashes not matching. BUT, its probably best to not
        # circumvent the check - its probably been hacked. This issue was actually addressed the day that I reported it.
        # Write-Warning( "$(Log-Date) 8th August 2018 All sysinternals versions fail with checksum error" ) | Write-Host
        # Write-Warning( "$(Log-Date) Running install ignoring checksums" ) | Write-Host
        # Run-ExitCode 'choco' @( 'install', 'sysinternals', '-y', '--no-progress', '--ignore-checksums' ) | Write-Host
        $_
        throw
    }


    # the --% is so that the rest of the line can use simpler quoting
    # See this link for full help on passing msiexec params through choco:
    # https://chocolatey.org/docs/commands-reference#how-to-pass-options-switches
    # This ensures that only English is installed as installing every language does not pass AWS virus checking
    Run-ExitCode 'choco' @( 'install', 'adobereader', '-y', '--no-progress', '--%', '-ia', 'LANG_LIST=en_US' )  | Write-Host

    # Delete a file that fails the AWS virus checker (LANSA EPC142040)
    Remove-Item 'c:\Program Files (x86)\Adobe\Acrobat Reader DC\Reader\plug_ins\pi_brokers\32BitMAPIBroker.exe'

    # JRE often fails to download with a 404, so install it explicitly from AWS S3
    # ( Latest choco seems to have fixed this)
    # $jreurl = 'jre-8u172-windows-x64.exe'
    # $jretarget = 'jre-8u172-windows-x64.exe'
    # Run-ExitCode $jre @( '/s' ) | Write-Host

    New-Item $ENV:TEMP -type directory -ErrorAction SilentlyContinue | Write-Host

    if ( $Cloud -eq "AWS" ) {
        Write-GreenOutput "$(Log-Date) Installing AWS SDK" | Write-Host
        &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
        Propagate-EnvironmentUpdate | Write-Host

        Write-GreenOutput "$(Log-Date) Installing AWS CLI" | Write-Host
        &"$Script:IncludeDir\installAwsCli.ps1" $TempPath | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
        Add-DirectoryToEnvPathOnce -Directory "c:\Program Files\Amazon\AWSCLI" | Write-Host
        }

    if ( $Cloud -eq "Azure" ) {
        Write-GreenOutput "$(Log-Date) Installing AzCopy" | Write-Host
        &"$Script:IncludeDir\installAzCopy.ps1" $TempPath | Write-Host
    }

    Write-Output "$(Log-Date) Running scheduleTasks.ps1" | Write-Host
    &"$Script:IncludeDir\scheduleTasks.ps1" | Write-Host
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

    Write-Output "$(Log-Date) Running Get-StartupCmds.ps1" | Write-Host
    &"$Script:IncludeDir\Get-StartupCmds.ps1" | Write-Host

    Write-Output "$(Log-Date) Disable IE Enhanced Security Configuration so that Flash executes OK in LANSA eLearning" | Write-Host
    Disable-InternetExplorerESC | Write-Host

     if ( $Cloud -eq "AWS" ) {
        # Delete file which causes AWS to falsely detect that there is a virus
        # Conditioned on AWS as do not know the user name on Azure, and Azure does not complain. After all, its not a real virus!
        Remove-Item c:\Users\Administrator\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Write-Host
        Remove-Item c:\Users\Default\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Write-Host
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
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Write-Host
    Write-RedOutput "install-lansa-base.ps1 is the <No file> in the stack dump below" | Write-Host
    throw
}

PlaySound

# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0