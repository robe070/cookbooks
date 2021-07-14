$Cloud = (Get-ItemProperty -Path HKLM:\Software\LANSA -Name 'Cloud').Cloud
if ($Cloud -eq "AWS") {
    Write-Host "Check if Amazon SSM Agent is running or not"
    $Count = 20
    $timeout = 20
    for ($i = 0; $i -lt $Count; $i++ ) {
        $SSMService = Get-Service -Name "Amazon SSM Agent" -ErrorAction SilentlyContinue
        if ( $SSMService.Status -eq "Running" ) {
            Write-Host "Amazon SSM Agent is running"
            break;
        }

        Write-Host "Waiting for Amazon SSM Agent to start"
        Start-Sleep $timeout
    }

    if ( $i -ge $count) {
        cmd /c exit 1 #Set $LASTEXITCODE
        throw "Amazon SSM Agent is not running"
    }
} elseif ( $Cloud -eq "" ) {
    cmd /c exit 1 #Set $LASTEXITCODE
    throw "Cloud registry entry is empty"
}
