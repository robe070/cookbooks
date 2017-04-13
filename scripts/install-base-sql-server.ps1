<#
.SYNOPSIS

Install miscellaenous stuff. Only vaguely related to SQL Server now.
Required because this cannot be executed remotely. It must be executed directly on the machine
   C:\Windows\system32\dism.exe /online /enable-feature /featurename:IIS-NetFxExtensibility /norestart  /All 


.EXAMPLE


#>

$OutputFile = "$ENV:TEMP\output1.txt"
$ErrorFile = "$ENV:TEMP\error1.txt"
$ResultFile = "$ENV:TEMP\resultcode1.txt"
Remove-Item -Path $OutputFile -ErrorAction SilentlyContinue
Remove-Item -Path $ErrorFile -ErrorAction SilentlyContinue
Remove-Item -Path $ResultFile -ErrorAction SilentlyContinue

# If environment not yet set up, it should be running locally, not through Remote PS
if ( -not $script:IncludeDir) {
    # Log-Date can't be used yet as Framework has not been loaded

	Write-Output "Initialising environment - presumed not running through RemotePS"
	$MyInvocation.MyCommand.Path
	$script:IncludeDir = Split-Path -Parent $MyInvocation.MyCommand.Path

	. "$script:IncludeDir\Init-Baking-Vars.ps1"
	. "$script:IncludeDir\Init-Baking-Includes.ps1"
}
else {
	Write-Output "$(Log-Date) Environment already initialised - presumed running through RemotePS"
}

try {
    #####################################################################################
    Write-Output ("$(Log-Date) Installing IIS-NetFxExtensibility") | Out-File $OutputFile -Append
    
    C:\Windows\system32\dism.exe /online /enable-feature /featurename:IIS-NetFxExtensibility /norestart  /All | Out-File $OutputFile -Append

    Write-Output ("$(Log-Date) Modifying Group Policy")  | Out-File $OutputFile -Append

    Run-ExitCode "$Script:IncludeDir\lgpo.exe" @('/m', "$Script:IncludeDir\lansa.pol")  | Out-File $OutputFile -Append

    Write-Output ("$(Log-Date) Installation completed successfully")  | Out-File $OutputFile -Append

    PlaySound

    # Successful completion so set Last Exit Code to 0
    cmd /c exit 0
}
catch {
	$_ | Out-File $ErrorFile -Append
    Write-Output ("$(Log-Date) Installation error")  | Out-File $ErrorFile -Append
    # Set LASTERRORCODE to a non-0 value
    if ( !$LASTEXITCODE -or $LASTEXITCODE -eq 0 ) {
        cmd /c exit 2
    }
    throw
}
Finally {
    # Produce output so that AWS Run Command Output Viewer gets the text and anything else which sees normal output
    # Errors first so that AWS RUN Command output viewer gets to see it at the top and probably not truuncate it.
    # Note that any errors occurring in functions which call Write-Error may not be captured and may already
    # have been captured by AWS Run Command before all this captured information is output. So, do not presume 
    # that the Result Code is on the first line of the output.
    Write-Output "$(Log-Date) Result Code = $LASTEXITCODE"
    Write-Output "$(Log-Date) Note that logging messages are re-ordered to workaround AWS Run Command truncating output, so the log date will seem to be out of order. You can piece it back together in chronological order if thats needed."

    Get-Content $ErrorFile -ErrorAction SilentlyContinue
    Get-Content $OutputFile -ErrorAction SilentlyContinue
    $LASTEXITCODE | Out-File $ResultFile
}
