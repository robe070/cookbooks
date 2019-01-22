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

# Silence all errors and allow git to report them as Exit Code, then test it.
# If you set it to 'Stop', git will throw for warnings too!
# And when executing as a batch job via the scheduler, extra error messages are produced, presumably because the scheduler redirects all output to the error handle
# And some warnings return a 0 exit code, but output to the error handle
# So, silence is the best option and manually determine how to handle each command.
$ErrorActionPreference = "SilentlyContinue"


try {
    push-location
    set-location $Directory

    Write-Host( "Getting latest changes...")
    git remote get-url origin | Write-Host
    if ( $LASTEXITCODE -ne 0) {
        throw "git remote get-url origin LASTEXITCODE = $LASTEXITCODE"
    }
    git pull | Write-Host
    if ( $LASTEXITCODE -ne 0) {
        throw "git pull LASTEXITCODE = $LASTEXITCODE"
    }

    Write-Host( "Adding a reference to the remote...")
    Write-Host( "Ignore already exists fatal error. Second and subsequent runs of this script will get an error on the next line, and the first time, if there is a real error here, a subsequent command will throw an error.")
    &git remote add $environmentName $TargetEnvironmentUrl | Write-Host
    if ( $LASTEXITCODE -ne 0 -and ($LASTEXITCODE -ne 128) ) {
        throw "git remote add $environmentName $TargetEnvironmentUrl LASTEXITCODE = $LASTEXITCODE"
    }

    Write-Host( "Remote $EnvironmentName configured to...")
    git remote get-url $environmentName | Write-Host
    if ( $LASTEXITCODE -ne 0) {
        throw "git remote get-url LASTEXITCODE = $LASTEXITCODE"
    }

    Write-Host( "Push the current branch to $EnvironmentName...")
    git push --force $environmentName | Write-Host
    if ( $LASTEXITCODE -ne 0) {
        throw "git push --force LASTEXITCODE = $LASTEXITCODE"
    }
} catch {
    Write-Host( "Exception")
    $_ | Write-Host
    $e = $_.Exception
    $e | format-list -force
    Write-Host( "Configuration failed" )
    # cmd /c exit -1 | Write-Host    #Set $LASTEXITCODE
    Write-Host( "LASTEXITCODE $LASTEXITCODE" )
    return
} finally {
    Write-Host( 'Common completion code')
    Pop-Location
}

Write-Host( "Configuration succeeded" )