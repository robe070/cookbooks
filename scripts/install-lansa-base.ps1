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

Write-Debug "script:IncludeDir = $script:IncludeDir"

try
{
    # Make sure Git is in the path
    Add-DirectoryToEnvPathOnce -Directory "C:\Program Files (x86)\Git\cmd"

    if (0)
    {
    cmd /c schtasks /change /TN "\Microsoft\windows\application Experience\ProgramDataUpdater" /DISABLE

    Write-Output "$(Log-Date) Installing Chef"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    $installer_file = "$GitRepoPath\PackerScripts\chef-client-12.1.1-1.msi"
    Start-Process -FilePath $installer_file -Wait 

    Write-Output "$(Log-Date) Running Chef"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\bin"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Add-DirectoryToEnvPathOnce -Directory "c:\opscode\chef\embedded"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Write-Debug $ENV:PATH
    cd "$GitRepoPath\Cookbooks"
    chef-client -z -o VLWebServer::IDEBase
    if ( $LASTEXITCODE -ne 0 )
    {
        $errorRecord = New-ErrorRecord System.Configuration.Install.InstallException RecipeFailure `
            InvalidData $LASTEXITCODE -Message "Chef-Client exit code = $LASTEXITCODE."
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    # Installing SQL Server Powershell tools separate to Chef because there is an error installing it 
    # when SQL 2014 is already installed, but it still works correctly with 2014.
    try
    {
        choco install SQL2012.Powershell
    }
    catch
    {
        # Ignore the expected errors
    }
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    Write-Output "$(Log-Date) Installing License"
    CreateLicence "$TempPath\LANSADevelopmentLicense.pfx" $LicenseKeyPassword "LANSA Development License" "DevelopmentLicensePrivateKey"
    }
    Write-Output "$(Log-Date) Installing AWS SDK"
    &"$Script:IncludeDir\installAwsSdk.ps1" $TempPath
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Propagate-EnvironmentUpdate

    Write-Output "$(Log-Date) Installing AWS CLI"
    &"$Script:IncludeDir\installAwsCli.ps1" $TempPath
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"
    Add-DirectoryToEnvPathOnce -Directory "c:\Program Files\Amazon\AWSCLI"

    Write-Output "$(Log-Date) Running scheduleTasks.ps1"
    &"$Script:IncludeDir\scheduleTasks.ps1"
    Write-Debug "Path = $([Environment]::GetEnvironmentVariable('PATH', 'Machine'))"

    Write-Output "$(Log-Date) Pulling down latest 13.x DVD Image of Visual LANSA"
    cmd /c mkdir 'c:\LanDVDcut' '2>nul'
    cmd /c "c:\Program Files\Amazon\AWSCLI\aws.exe" s3 sync "s3://lansa/releasedbuilds/v13/LanDVDcut_L4W13200_4088_latest" "c:\LanDVDcut" --exclude "*ibmi/*" --exclude "*AS400/*" --exclude "*linux/*" --exclude "*setup/Installs/MSSQLEXP/*" --delete
    
    Write-Output "$(Log-Date) Running Get-StartupCmds.ps1"
    &"$Script:IncludeDir\Get-StartupCmds.ps1"

    if (0)
    {
        # Windows Updates cannot be run remotely using Remote PS. Note that ssh server CAN run it!
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
# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0