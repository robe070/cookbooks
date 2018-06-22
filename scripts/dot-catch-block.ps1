# dot include this in a catch block for the top level script called remotely.
# Set $LASTEXITCODE before dot-including this file to use a non-standard error code
    Write-RedOutput $_ | Out-Host
    Write-RedOutput $PSItem.ScriptStackTrace | Out-Host
   
    Write-Host "" # A seperator line

    # Set a default error code
    if ( $LASTEXITCODE -eq 0 ) {
        cmd /c exit 1
    }

    return

