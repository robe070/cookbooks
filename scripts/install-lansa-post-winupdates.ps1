<#
.SYNOPSIS

Install the remaining parts of the base LANSA image one Windows Updates has been applied.

.DESCRIPTION

These tasks must all occur after Windows Updates. If they can be applied earlier, they should be applied earlier

.EXAMPLE


#>

param (
    [Parameter(Mandatory=$true)]
    [string]
    $GitRepoPath,

    [Parameter(Mandatory=$true)]
    [string]
    $TempPath
    )

try
{
    $Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Cloud').Cloud
    $Language = (Get-ItemProperty -Path HKLM:\Software\LANSA  -Name 'Language').Language

    Write-Host "$(Log-Date) Updating $Cloud instance, Language $Language"

    Write-Host "$(Log-Date) Synchronise clock"

    cmd /c "sc triggerinfo w32time start/networkon stop/networkoff" | Out-Default

    Write-Host "$(Log-Date) Ensure that Framework caching is completed"

    cmd /c "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Ngen executequeueditems" | Out-Null
    cmd /c "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Ngen executequeueditems" | Out-Null

    if ( $Cloud -eq "AWS" ) {
        if ( Test-Path $ENV:ProgramFiles\Amazon\Ec2ConfigService ) {
            Write-Host "$(Log-Date) Configure EC2 Settings"
            &"$Script:IncludeDir\Ec2ConfigSettings.ps1" "$TempPath" | Out-Default
            cmd /c del /F "$ENV:ProgramFiles\Amazon\Ec2ConfigService\Logs\*.txt" | Out-Default
        } else {
            # Newer EC2 Launch service
            cmd /c del /F "$ENV:ProgramData\Amazon\EC2-Windows\Launch\Log\*.*" | Out-Default
        }
    }

    Write-Host "$(Log-Date) Tidy up"

    if (Test-Path -Path $TempPath) {
        cmd /c rd /S/Q $TempPath | Out-Host
    }

    if ( $Cloud -eq "Azure " -and ($Language -ne 'ENG') ) {
        Set-ItemProperty -Path "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" -Name "StartHere" -Value "powershell -executionpolicy Bypass -file $GitRepoPath_\scripts\recover-language-pack.ps1" | Out-Default
    }
}
catch
{
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Out-Default
    Write-RedOutput "install-lansa-post-winupdates.ps1 is the <No file> in the stack dump below" | Out-Default
    throw
}