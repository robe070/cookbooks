Write-Host "=== PowerShell Gallery Connectivity Test ===" -ForegroundColor Cyan

# Expected PSGallery URLs
$urls = @(
    "https://www.powershellgallery.com/api/v2/",
    "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='Az.Websites'",
    "https://www.powershellgallery.com/api/v2/Search()?searchTerm='Az'",
    "https://www.powershellgallery.com/api/v2/Search()?searchTerm='Az.Websites'"
)

Write-Host "`n--- Testing raw HTTPS connectivity ---`n"

foreach ($u in $urls) {
    try {
        $res = Invoke-WebRequest -Uri $u -UseBasicParsing -TimeoutSec 20
        Write-Host "[OK]  $u  → $($res.StatusCode)" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] $u" -ForegroundColor Red
        Write-Host "       $($_.Exception.Message)"
    }
}

Write-Host "`n--- Testing TLS protocols ---`n"
foreach ($tls in @([Net.SecurityProtocolType]::Tls12, [Net.SecurityProtocolType]::Tls13)) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = $tls
        Invoke-WebRequest "https://www.powershellgallery.com/api/v2/" -UseBasicParsing -TimeoutSec 10 | Out-Null
        Write-Host "[OK] TLS $tls works"
    }
    catch {
        Write-Host "[FAIL] TLS $tls failed"
        Write-Host $_.Exception.Message
    }
}


Write-Host "`n--- Testing PowerShell repository metadata ---`n"
try {
    Get-PSRepository | Format-Table Name, SourceLocation, InstallationPolicy
}
catch {
    Write-Host "[FAIL] Get-PSRepository" -ForegroundColor Red
    Write-Host "       $($_.Exception.Message)"
}

Write-Host "`n--- Testing PowerShellGet provider ---`n"
try {
    Get-PackageProvider -ListAvailable | Where-Object { $_.Name -like "PowerShellGet" } | Format-Table Name, Version
}
catch {
    Write-Host "[FAIL] Provider check failed" -ForegroundColor Red
}

Write-Host "`n--- Attempting Find-Module Az ---`n"
try {
    Find-Module Az -ErrorAction Stop | Format-List Name, Version, Repository
    Write-Host "[OK] Find-Module completed" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Find-Module failed" -ForegroundColor Red
}

Write-Host "`n--- Attempting Find-Module (baseline test) ---`n"
try {
    Find-Module Az.Websites -ErrorAction Stop | Format-List Name, Version, Repository
    Write-Host "[OK] Find-Module completed" -ForegroundColor Green
}
catch {
    Write-Host "[FAIL] Find-Module failed" -ForegroundColor Red
}

Write-Host "`n=== End of Test ==="
