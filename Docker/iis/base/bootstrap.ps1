## this is an alternative to using ServiceMonitor
Write-Host ("bootstrap.ps1 starting")

# copy process-level environment variables to machine level
foreach($key in [System.Environment]::GetEnvironmentVariables('Process').Keys) {
    if ($null -eq [System.Environment]::GetEnvironmentVariable($key, 'Machine')) {
        $value = [System.Environment]::GetEnvironmentVariable($key, 'Process')
        [System.Environment]::SetEnvironmentVariable($key, $value, 'Machine')
    }
}

# echo the IIS log to the console:
Start-Service W3SVC
$probeUris = @('http://localhost', 'http://127.0.0.1')
Write-Host "Probing IIS for readiness at $($probeUris -join ', ')"
$probeSucceeded = $false
foreach ($probeUri in $probeUris) {
    for ($attempt = 1; $attempt -le 10; $attempt++) {
        try {
            Invoke-WebRequest $probeUri -UseBasicParsing | Out-Null
            $probeSucceeded = $true
            break
        } catch {
            if ($attempt -eq 10) {
                Write-Warning ("IIS readiness probe failed for {0} after {1} attempts. {2}" -f $probeUri, $attempt, $_.Exception.Message)
            } else {
                Start-Sleep -Seconds 2
            }
        }
    }

    if ($probeSucceeded) {
        break
    }
}

if (-not $probeSucceeded) {
    throw "IIS did not become ready after repeated readiness probes."
}

netsh http flush logbuffer | Out-Null
Get-Content -path 'C:\iislog\W3SVC\u_extend1.log' -Tail 1 -Wait