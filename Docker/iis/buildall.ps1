param (
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all',

    [Parameter(Mandatory=$false)]
    [string]
    $VersionNum = "16.0.0",

    [Parameter(Mandatory=$false)]
    [switch]
    $ClearCache,

    [Parameter(Mandatory=$false)]
    [switch]
    $Trace,

    [Parameter(Mandatory=$false)]
    [string]
    $Cloud
)

try {
    Push-Location base -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
    Pop-Location -StackName Docker

    Push-Location AWAMAPP -StackName Docker
    .\buildall.ps1 -DockerLabel $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
    Pop-Location -StackName Docker

    # Push-Location vlweb -StackName Docker
    # .\buildall.ps1 -DockerLabel $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
    # Pop-Location -StackName Docker

    # Push-Location webserver -StackName Docker
    # .\buildall.ps1 -DockerLabel $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
    # Pop-Location -StackName Docker

    # Push-Location addapp -StackName Docker
    # .\buildall.ps1 -DockerLabel $DockerLabel -VersionNum $VersionNum -ClearCache:$ClearCache -Trace:$Trace -Cloud $Cloud
    # Pop-Location -StackName Docker

} catch {
    $_
    Pop-Location -StackName Docker
    throw
} finally {
    Write-Host("************************************************************************************************")
}
