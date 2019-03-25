# presumes that these directories exist:
# c:\temp mapped to host temporary directory
# c:\lansa to host  Cookbooks
# c:\lansa container directory for the msi location
# c:\debugger to host remote debugger directory e.g. C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\Remote Debugger\x86

try {
    Push-Location

    cd c:\debugger
    Start-Process -FilePath .\msvsmon.exe -ArgumentList '/nosecuritywarn /noauth /anyuser /prepcomputer /port:4020 /silent' -Verb runAs

} catch {
    $_
    Write-Host ("Failed")
    cmd /c exit -1
    exit
} finally {
    Pop-Location
    Write-Host ("Finished")
}
Write-Host( "Successful")
cmd /c exit 0