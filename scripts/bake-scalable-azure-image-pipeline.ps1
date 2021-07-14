<#
.SYNOPSIS

Generic script to Bake a LANSA image for Azure

.DESCRIPTION
Used by Image Pipeline
.EXAMPLE


#>
param (
    [Parameter(Mandatory=$true)]
    [string]
    $VersionText,

    [Parameter(Mandatory=$true)]
    [int]
    $VersionMajor,

    [Parameter(Mandatory=$true)]
    [int]
    $VersionMinor,

    [Parameter(Mandatory=$true)]
    [string]
    $AmazonAMIName,

    [Parameter(Mandatory=$true)]
    [string]
    $GitBranch,

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud='AWS',

    [Parameter(Mandatory=$false)]
    [boolean]
    $Win2012=$true,

    [Parameter(Mandatory=$false)]
    [boolean]
    $AtomicBuild=$false,

    [Parameter(Mandatory=$false)]
    [string]
    $KeyPairName="RobG_id_rsa",

    [Parameter(Mandatory=$false)]
    [string]
    $KeyPairPath="$ENV:USERPROFILE\\.ssh\\id_rsa",

    [Parameter(Mandatory=$false)]
    [string]
    $GitUserName="robe070",

    [Parameter(Mandatory=$false)]
    [int]
    $MaxRetry=10,

    [Parameter(Mandatory=$false)]
    [boolean]
    $RunWindowsUpdates=$false
    )

# $DebugPreference = "Continue"
$VerbosePreference = "Continue"

$MyInvocation.MyCommand.Path
$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

. "$Script:IncludeDir\bake-ide-ami.ps1"

###############################################################################
# Main program logic
###############################################################################

Set-StrictMode -Version Latest
$count =  $MaxRetry
$result = $null
while($count -ne 0 ) {
    try {
        $result = Bake-IdeMsi -VersionText $VersionText `
                            -VersionMajor $VersionMajor `
                            -VersionMinor $VersionMinor `
                            -LocalDVDImageDirectory "\\devsrv\ReleasedBuilds\v14\SPIN0332_LanDVDcut_L4W14100_4138_160727_GA" `
                            -S3DVDImageDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/LanDVDcut_L4W14000_latest" `
                            -S3VisualLANSAUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/VisualLANSA_L4W14000_latest" `
                            -S3IntegratorUpdateDirectory "https://lansalpcmsdn.blob.core.windows.net/releasedbuilds/v14/Integrator_L4W14000_latest" `
                            -AmazonAMIName $AmazonAMIName `
                            -GitBranch $GitBranch `
                            -Cloud $Cloud `
                            -InstallBaseSoftware $true `
                            -InstallSQLServer $false `
                            -InstallIDE $false `
                            -InstallScalable $true `
                            -Win2012 $Win2012 `
                            -ManualWinUpd $false `
                            -SkipSlowStuff $false `
                            -OnlySaveImage $false `
                            -CreateVM $true `
                            -Pipeline:$true `
                            -KeyPairName $KeyPairName `
                            -KeyPairPath $KeyPairPath `
                            -GitUserName $GitUserName `
                            -AtomicBuild:$AtomicBuild `
                            -RunWindowsUpdates $RunWindowsUpdates `
                            -ExternalIPAddresses

    }
    catch{
        $PSitem | Out-Default | Write-Host
        $count = $count -1
        if($count -eq 0){
            Write-Host "Image Bake failed even after $MaxRetry retries"
            break
        }
        elseif ($Cloud -eq 'AWS'){
            Write-Host "Image bake failed. Retry number : $($MaxRetry - $count + 1)"
        }
    }
    if($result -eq "Success") {
        Write-Host "Image bake succesful: Retry number : $($MaxRetry - $count + 1)"
        break
    }
    if($Cloud -eq 'Azure'){
        Write-Host "Image bake failed. Retry not enabled in Azure"
        break
    }



}

