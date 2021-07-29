# Invoke Pester Tests
cd $(System.DefaultWorkingDirectory)\Tests
$result = Invoke-Pester -Script '.\Image*' -OutputFormat  NUnitXml -OutputFile '$(System.DefaultWorkingDirectory)\Test-Vm.xml' -PassThru
$result | Out-Default | Write-Host
if ($result.Result -eq "Failed") {
    throw "Failed Tests Count: $($result.FailedCount)"
} else {
    Write-Host "Tested the image successfully."
}
