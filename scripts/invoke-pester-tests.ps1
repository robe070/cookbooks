
# Invoke Pester Tests
cd "$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)/Tests"
$result = Invoke-Pester -Script '.\Image*' -OutputFormat  NUnitXml -OutputFile "$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)/Test-Vm.xml" -PassThru
Write-Host "result is - $result"
if ($result.Result -eq "Failed") {
    throw "Failed Tests Count: $($result.FailedCount)"
} else {
    Write-Host "Tested the image successfully."
}
