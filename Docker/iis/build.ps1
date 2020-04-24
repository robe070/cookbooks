param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('1903','1909', 'ltsc2019', 'ltsc2016')]
    [string]
    $DockerLabel='1909'
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