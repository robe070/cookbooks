﻿
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

    [string]
    $LicenseKeyPassword,

    [Parameter(Mandatory=$true)]
    [string]
    $ChefRecipe
    )

Write-Debug "script:IncludeDir = $script:IncludeDir" | Write-Host

function ChocoWait([int] $WaitTimeSeconds = 60) {
    Write-Host "$(Log-Date) Adding Wait for Choco" | Write-Host
    Start-Sleep -Seconds $WaitTimeSeconds
}
function DownloadAndInstallMSI {
    param (
        [string] $MSIuri,
        [string] $installer_file,
        [string] $log_file
    )
    Write-Host ("$(Log-Date) Downloading $MSIuri to $installer_file")
    $downloaded = $false
    $TotalFailedDownloadAttempts = 0
    $loops = 0
    while (-not $Downloaded -and ($Loops -le 10) ) {
        try {
            (New-Object System.Net.WebClient).DownloadFile($MSIuri, $installer_file) | Out-Default | Write-Host
            $downloaded = $true
        } catch {
            $TotalFailedDownloadAttempts += 1
            $loops += 1

            Write-Host ("$(Log-Date) Total Failed Download Attempts = $TotalFailedDownloadAttempts")

            if ($loops -gt 10) {
                throw "Failed to download $MSIuri from S3"
            }

            # Pause for 30 seconds. Maybe that will help it work?
            Start-Sleep 30
        }
    }

    $p = Start-Process -FilePath $installer_file -ArgumentList @('/qn', "/lv*x $log_file") -Wait -PassThru
    if ( $p.ExitCode -ne 0 ) {
        $ExitCode = $p.ExitCode
        $ErrorMessage = "MSI Install of $MSIuri returned error code $($p.ExitCode)."
        throw $ErrorMessage
    }
}

try
{
    # If environment not yet set up, it should be running locally, not through Remote PS
    if ( -not $script:IncludeDir)
    {
        # Log-Date can't be used yet as Framework has not been loaded

        Write-Host "Initialising environment - presumed not running through RemotePS"
        $MyInvocation.MyCommand.Path
        $script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

        . "$script:IncludeDir\Init-Baking-Vars.ps1"
        . "$script:IncludeDir\Init-Baking-Includes.ps1"
    }
    else
    {
        Write-Host "$(Log-Date) Environment already initialised - presumed running through RemotePS"
    }

    if ( !(test-path $TempPath) ) {
        New-Item $TempPath -type directory -ErrorAction SilentlyContinue | Write-Host
    }

    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $InstallSQLServer = $false
    $InstallSQLServer = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'InstallSQLServer' -ErrorAction SilentlyContinue).InstallSQLServer

    # Check if SQL Server is already installed
    $mssql_services = Get-WmiObject win32_service | where-object name -like 'MSSQL*'
    If ( $null -eq $mssql_services -and ( -not $InstallSQLServer ) ) {
        # So SQL Server not installed and we are not planning on installing it, so install whats required to use the sqlps module
        DownloadAndInstallMSI -MSIuri 'https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/SQLSysClrTypes.msi' -installer_file (Join-Path $temppath 'SQLSysClrTypes.msi') -log_file (Join-Path $temppath 'SQLSysClrTypes.log');
        DownloadAndInstallMSI -MSIuri 'https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/SharedManagementObjects.msi' -installer_file (Join-Path $temppath 'SharedManagementObjects.msi') -log_file (Join-Path $temppath 'SharedManagementObjects.log');
        DownloadAndInstallMSI -MSIuri 'https://lansa.s3-ap-southeast-2.amazonaws.com/3rd+party/PowerShellTools.MSI' -installer_file (Join-Path $temppath 'PowerShellTools.msi') -log_file (Join-Path $temppath 'PowerShellTools.log');
    }

    Write-Host "Clear the UTF-8 system locale option. If already switched off this code has no effect"
    $Locale =  Get-WinSystemLocale
    Write-Host "Current Locale = $($Locale.name)"
    Set-WinSystemLocale $Locale.Name

    # Chef installation
    if ( $Cloud -ne "Docker" ) {
        Run-ExitCode 'schtasks' @( '/change', '/TN', '"\Microsoft\windows\application Experience\ProgramDataUpdater"', '/Disable' ) | Out-Default | Write-Host

        Write-GreenOutput "$(Log-Date) Installing Chef" | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

        $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
        Run-ExitCode 'msiexec.exe' @( '/i', $installer_file, '/qn' ) | Write-Host

        Write-GreenOutput "$(Log-Date) Running Chef" | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
        Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin" | Out-Default | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
        Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded" | Out-Default | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
        Write-Debug $ENV:PATH | Write-Host
        cd "$GitRepoPath\Cookbooks" | Out-Default | Write-Host

        chef-client -z -o $ChefRecipe | Out-Default | Write-Host
        if ( $LASTEXITCODE -ne 0 )
        {
            throw "Chef-Client exit code = $LASTEXITCODE."
        }
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

        # Make sure Git is in the path. Adding it in a prior script it gets 'lost' when Chef Zero is Run in this script
        Add-DirectoryToEnvPathOnce -Directory "C:\Program Files\Git\cmd" | Out-Default | Write-Host
        Add-DirectoryToEnvPathOnce -Directory "C:\ProgramData\chocolatey\bin\" | Out-Default | Write-Host

        Write-Debug $ENV:PATH | Write-Host
    }

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
                (New-Object System.Net.WebClient).DownloadFile($CWASetup, $installer_file) | Out-Default | Write-Host
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

        Write-GreenOutput( "$(Log-Date) Unzipping $installer_file to $InstallerDirectory") | Out-Default | Write-Host
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
        Set-Location $InstallerDirectory | Out-Default | Write-Host
        & $InstallerScript | Out-Default | Write-Host

        # Start CloudWatchAgent so that the service gets installed, so that it can be stopped and set to manual!!
        # CF template then configures it but does not start it. Its intended to only be enabled through Systems Manager
        .\amazon-cloudwatch-agent-ctl.ps1 -a start -s

        Write-Host( "$(Log-Date) Set Cloud Watch Agent Service to manual")
        set-service -Name AmazonCloudWatchAgent -StartupType Manual | Out-Default | Write-Host
        stop-service -Name AmazonCloudWatchAgent | Out-Default | Write-Host
        get-service AmazonCloudWatchAgent | SELECT-OBJECT Name, StartType, Status | Out-Default | Write-Host
    }

    # GUI Application Installation
    if ( $Cloud -ne "Docker" ) {
        Run-ExitCode 'choco' @( 'install', 'googlechrome', '-y', '--no-progress','--ignore-checksums', '-s choco' ) | Write-Host
        ChocoWait
        # Run-ExitCode 'choco' @( 'install', 'gitextensions', '-y', '--no-progress', '--version 2.51.5')  | Out-Host # v3.2 failed to install. v3.1.1 installs a Windows Update which cannot be done through WinRM. Same with 2.51.5. So don't install it. Can be installed manually if required.
        # JRE needs to be replaced with the VL Main Install method: OpenJDK is just a zip file. We unzip it into the Integrator\Java directory. The root folder in the zip file is the version. We ship OpenJDKShippedVersion.txt (our file) with the zip file which I copy into the Integrator\Java directory so we know the directory to use when doing things like the install creating the shortcuts.
        Run-ExitCode 'choco' @( 'install', 'jre8', '-y', '--no-progress', '-PackageParameters "/exclude:32"', '-s choco' ) | Write-Host
        ChocoWait

        try {
            Start-Sleep -Seconds 20
            "$(Log-Date) Add a 20s sleep before installing kdiff3 from choco" | Write-Host
            Run-ExitCode 'choco' @( 'install', 'kdiff3', '-y', '--no-progress',  '-s choco' ) | Write-Host
            ChocoWait
        }
        catch {
            Write-Host "$(Log-Date) Add a 300s sleep before retry installing kdiff3 from choco" | Out-Default
            Write-Host $_ | Out-Default
            ChocoWait 300
            Run-ExitCode 'choco' @( 'install', 'kdiff3', '-y', '--no-progress', '-s choco' ) | Write-Host
            ChocoWait
        }

        Run-ExitCode 'choco' @( 'install', 'vscode', '-y', '--no-progress', '-s choco' ) | Write-Host
        ChocoWait
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
        # Run-ExitCode 'choco' @( 'install', 'adobereader', '-y', '--no-progress', '--%', '-ia', 'LANG_LIST=en_US' )  | Out-Host

        # Stop using Adobe Reader because it was dependent on a Windows Update that could not be installed on Win 2012 because it was obsolete.
        Run-ExitCode 'choco' @( 'install', 'foxitreader', '-y', '--no-progress', '-s choco' )  | Out-Host
        ChocoWait

        # JRE often fails to download with a 404, so install it explicitly from AWS S3
        # ( Latest choco seems to have fixed this)
        # $jreurl = 'jre-8u172-windows-x64.exe'
        # $jretarget = 'jre-8u172-windows-x64.exe'
        # Run-ExitCode $jre @( '/s' ) | Write-Host

        New-Item $ENV:TEMP -type directory -ErrorAction SilentlyContinue | Out-Default | Write-Host

        if ( $Cloud -eq "AWS" ) {
            Write-GreenOutput "$(Log-Date) Installing AWS SDK" | Write-Host
            &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath | Out-Default | Write-Host
            Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
            Propagate-EnvironmentUpdate | Out-Default | Write-Host

            Write-GreenOutput "$(Log-Date) Installing AWS CLI" | Write-Host
            &"$Script:IncludeDir\installAwsCli.ps1" $TempPath | Out-Default | Write-Host
            Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host
            Add-DirectoryToEnvPathOnce -Directory "c:\Program Files\Amazon\AWSCLI" | Out-Default | Write-Host
            }

        if ( $Cloud -eq "Azure" ) {
            Write-GreenOutput "$(Log-Date) Installing AzCopy" | Write-Host
            &"$Script:IncludeDir\installAzCopy.ps1" $TempPath | Out-Default | Write-Host
        }

        Write-Host "$(Log-Date) Running scheduleTasks.ps1"
        &"$Script:IncludeDir\scheduleTasks.ps1" | Out-Default | Write-Host
        Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))" | Write-Host

        Write-Host "$(Log-Date) Running Get-StartupCmds.ps1"
        &"$Script:IncludeDir\Get-StartupCmds.ps1" | Out-Default | Write-Host

        Write-Host "$(Log-Date) Disable IE Enhanced Security Configuration so that Flash executes OK in LANSA eLearning"
        Disable-InternetExplorerESC | Out-Default | Write-Host

        if ( $Cloud -eq "AWS" ) {
            # Delete file which causes AWS to falsely detect that there is a virus
            # Conditioned on AWS as do not know the user name on Azure, and Azure does not complain. After all, its not a real virus!
            Remove-Item c:\Users\Administrator\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Out-Default | Write-Host
            Remove-Item c:\Users\Default\.chef\local-mode-cache\cache\vcredist2013_x64.exe -Confirm:$false -Force -ErrorAction:SilentlyContinue | Out-Default | Write-Host
        }

    }
}
catch
{
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Write-Host
    Write-RedOutput "install-lansa-base.ps1 is the <No file> in the stack dump below" | Write-Host
    throw
}

if ( $Cloud -ne "Docker" ) {
    PlaySound
}

# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0