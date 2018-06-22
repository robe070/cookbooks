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
    Write-Host "$(Log-Date) Updating $Cloud instance"

    Write-Host "$(Log-Date) Synchronise clock"

    cmd /c "sc triggerinfo w32time start/networkon stop/networkoff" | Out-Host

    Write-Host "$(Log-Date) Ensure that Framework caching is completed"

    cmd /c "C:\Windows\Microsoft.NET\Framework\v4.0.30319\Ngen executequeueditems" | Out-Host
    cmd /c "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Ngen executequeueditems" | Out-Host

    if ( $Cloud -eq "AWS" ) {
        if ( Test-Path $ENV:ProgramFiles\Amazon\Ec2ConfigService ) {
            Write-Host "$(Log-Date) Configure EC2 Settings"
            &"$Script:IncludeDir\Ec2ConfigSettings.ps1" "$TempPath" | Out-Host
            cmd /c del /F "$ENV:ProgramFiles\Amazon\Ec2ConfigService\Logs\*.txt" | Out-Host
        } else {
            # Newer EC2 Launch service
            cmd /c del /F "$ENV:ProgramData\Amazon\EC2-Windows\Launch\Log\*.*" | Out-Host
        }
    }

    Write-Host "$(Log-Date) Tidy up"

    if (Test-Path -Path $TempPath) {
        cmd /c rd /S/Q $TempPath | Out-Host
    }
}
catch
{
    Write-RedOutput "install-lansa-post-winupdates.ps1 is the <No file> in the stack dump below" | Out-Host
    . "$Script:IncludeDir\dot-catch-block.ps1"
}