try {
    Push-Location base -StackName Docker
    .\buildall.ps1
    Pop-Location -StackName Docker

    Push-Location webserver -StackName Docker
    .\buildall.ps1
    Pop-Location -StackName Docker

    Push-Location vlweb -StackName Docker
    .\buildall.ps1
    Pop-Location -StackName Docker
} catch {
    $_
    Pop-Location -StackName Docker
    throw
} finally {
    Write-Host("************************************************************************************************")
}