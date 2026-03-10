param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('ltsc2025', 'all')]
    [string]
    $DockerLabel='all'
)
try {
    Push-Location base -StackName Docker
    .\build.ps1 $DockerLabel
    Pop-Location -StackName Docker

    Push-Location webserver -StackName Docker
    .\build.ps1 $DockerLabel
    Pop-Location -StackName Docker

    Push-Location vlweb -StackName Docker
    .\build.ps1 $DockerLabel
    Pop-Location -StackName Docker

} catch {
    Pop-Location -StackName Docker
}


