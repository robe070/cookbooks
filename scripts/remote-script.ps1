
<#
.SYNOPSIS

script to be executed remotely for testing

.DESCRIPTION

.EXAMPLE


#>
   
Write-Debug "script:IncludeDir = $script:IncludeDir" | Out-Host

try
{
    Run-ExitCode 'choco' @( 'install', 'googlechrome', '-y', '--no-progress' ) | Out-Host
}
catch
{
    $Global:LANSAEXITCODE = $LASTEXITCODE
    Write-RedOutput "Remote-Script LASTEXITCODE = $LASTEXITCODE" | Out-Host

    Write-RedOutput "remote-script.ps1 is the <No file> in the stack dump below" | Out-Host
    throw
}

PlaySound

# Ensure last exit code is 0. (exit by itself will terminate the remote session)
cmd /c exit 0