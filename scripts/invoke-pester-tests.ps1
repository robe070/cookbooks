
# Invoke Pester Tests
cd "$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)/Tests"
ls
#$result = Invoke-Pester -Script '.\Image*' -OutputFormat  NUnitXml -OutputFile '$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)\Test-Vm.xml' -PassThru
#$result | Out-Default | Write-Host
#if ($result.Result -eq "Failed") {
#    throw "Failed Tests Count: $($result.FailedCount)"
#} else {
#    Write-Host "Tested the image successfully."
#}
