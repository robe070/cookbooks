
# Invoke Pester Tests
cd $($env:System_DefaultWorkingDirectory)\Tests
$result = Invoke-Pester -Script '.\Image*' -OutputFormat  NUnitXml -OutputFile '$($env:System_DefaultWorkingDirectory)\Test-Vm.xml' -PassThru
$result | Out-Default | Write-Host
if ($result.Result -eq "Failed") {
    throw "Failed Tests Count: $($result.FailedCount)"
} else {
    Write-Host "Tested the image successfully."
}
