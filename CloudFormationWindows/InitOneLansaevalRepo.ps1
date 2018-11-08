# Initialise git repo related to a specific app in a specific stack

param(
[Parameter(Mandatory=$true)]
[String]$TargetEnvironmentUrl,

[Parameter(Mandatory=$true)]
[String]$EnvironmentName,

[Parameter(Mandatory=$false)]
[String]$Directory = 'c:\lansa\lansaeval-master'
)
"InitOneLansaevalRepo.ps1" | Write-Host

cmd /c exit 0 #Set $LASTEXITCODE

try {
    push-location
    set-location $Directory

    Write-Host( "Getting latest changes...")
    git remote get-url origin
    git pull

    try {
        $ErrorActionPreference = "Continue"
        Write-Host( "Second and subsequent runs of this script will get an error on the next line. Ignore it" )
        &git remote add $environmentName $TargetEnvironmentUrl
    } catch {
        Write-Host( "git remote add : LASTEXITCODE $LASTEXITCODE" )
    }
    $ErrorActionPreference = "Stop"

    Write-Host( "Remote $EnvironmentName configured to...")
    git remote get-url $environmentName

    Write-Host( "Push the current branch to $EnvironmentName...")
    git push --force $environmentName
} catch {
    Write-Host( "Exception")
    $_ | Write-Host
    $e = $_.Exception
    $e | format-list -force
    Write-Host( "Configuration failed" )
    cmd /c exit -1 | Write-Host    #Set $LASTEXITCODE
    Write-Host( "LASTEXITCODE $LASTEXITCODE" )
    return
} finally {
    Write-Host( 'Common completion code')
    Pop-Location
}

Write-Host( "Configuration succeeded" )