<#
.SYNOPSIS

Bake a LANSA AMI

.DESCRIPTION

.EXAMPLE


#>

$DebugPreference = "SilentlyContinue"
$VerbosePreference = "SilentlyContinue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$script:IncludeDir\Init-Baking-Vars.ps1"
. "$script:IncludeDir\Init-Baking-Includes.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest
$Cloud = "AWS"
$VersionText = "V15 GA"
$LocalDVDImageDirectory = "\\devsrv\ReleasedBuilds\v15\SPIN00340_LanDVDcut_L4W15000_4403_200402_GA"
$S3DVDImageDirectory = "s3://lansa/releasedbuilds/v15/LanDVDcut_L4W15000_latest"

Write-Host ("Test if source of DVD image exists")
if ( !(Test-Path -Path $LocalDVDImageDirectory) )
{
    throw "LocalDVDImageDirectory '$LocalDVDImageDirectory' does not exist."
}

if ( $Cloud -eq 'AWS' ) {
    # Standard arguments. Triple quote so we actually pass double quoted parameters to aws S3
    # MSSQLEXP excludes ensure that just 64 bit english is uploaded.
    [String[]] $S3Arguments = @("--exclude", "*ibmi/*", "--exclude", "*AS400/*", "--exclude", "*linux/*", "--exclude", "*setup/Installs/MSSQLEXP/*_x86_*.exe", "--exclude", "*setup/Installs/MSSQLEXP/*_x64_JPN.exe", "--delete")

    # If its not a beta, allow everyone to access it
    if ( $VersionText -ne "14beta" )
    {
        $S3Arguments += @("--grants", "read=uri=http://acs.amazonaws.com/groups/global/AllUsers")
    }
    cmd /c aws s3 sync  $LocalDVDImageDirectory $S3DVDImageDirectory $S3Arguments | Write-Host
    if ( $LastExitCode -ne 0 ) { throw }
} elseif ( $Cloud -eq 'Azure' ) {
    # This is broken. Needs to be fixed when required.
    $StorageAccount = 'lansalpcmsdn'

    #Save the storage account key
    $StorageKey = (Get-AzureStorageKey -StorageAccountName $StorageAccount).Primary
    Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory directory")
    cmd /c AzCopy /Source:$LocalDVDImageDirectory            /Dest:$S3DVDImageDirectory            /DestKey:$StorageKey    /XO /Y | Write-Host
    Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\3rdparty directory")
    cmd /c AzCopy /Source:$LocalDVDImageDirectory\3rdparty   /Dest:$S3DVDImageDirectory/3rdparty   /DestKey:$StorageKey /S /XO /Y | Write-Host
    Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\Integrator directory")
    cmd /c AzCopy /Source:$LocalDVDImageDirectory\Integrator /Dest:$S3DVDImageDirectory/Integrator /DestKey:$StorageKey /S /XO /Y | Write-Host
    Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\Setup directory")
    cmd /c AzCopy /Source:$LocalDVDImageDirectory\setup      /Dest:$S3DVDImageDirectory/setup      /DestKey:$StorageKey /S /XO /Y | Write-Host
    Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\html directory")
    cmd /c AzCopy /Source:$LocalDVDImageDirectory\html      /Dest:$S3DVDImageDirectory/html        /DestKey:$StorageKey /S /XO /Y | Write-Host

    if ( (Test-Path -Path $LocalDVDImageDirectory\epc) ) {
        Write-Host ("$(Log-Date) Copy $LocalDVDImageDirectory\epc directory")
        cmd /c AzCopy /Source:$LocalDVDImageDirectory\epc    /Dest:$S3DVDImageDirectory/epc        /DestKey:$StorageKey /S /XO /Y | Write-Host
    }
}
