Write-Host("curl.exe is required for licensing and other operations, but is not included in the base Windows image. Download and install it from the official source.")
$curlZip = "C:\temp\curl.zip"
$curlDir = "C:\tools\curl"
$curlUri = "https://curl.se/windows/latest.cgi?p=win64-mingw.zip"
$curlSha256Uri = "https://curl.se/windows/latest.cgi?p=win64-mingw.zip.txt"

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Force -Path (Split-Path $curlZip) | Out-Null
Invoke-WebRequest -Uri $curlUri -OutFile $curlZip
$checksumResponse = (Invoke-WebRequest -Uri $curlSha256Uri).Content.Trim()
$checksumMatch = [regex]::Match($checksumResponse, '=\s*([0-9a-fA-F]{64})\s*$')
if (-not $checksumMatch.Success) {
    throw "Unable to parse SHA256 from $curlSha256Uri. Response: $checksumResponse"
}

$expectedSha256 = $checksumMatch.Groups[1].Value.ToLowerInvariant()
$actualSha256 = (Get-FileHash -Path $curlZip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($actualSha256 -ne $expectedSha256) {
    throw "curl.zip SHA256 mismatch. Expected $expectedSha256 but got $actualSha256"
}

Expand-Archive -Path $curlZip -DestinationPath $curlDir -Force

# Add to PATH for current session
$bin = Get-ChildItem -Path $curlDir -Directory | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "bin" }
$env:Path = "$env:Path;$bin"

# Optional: make it persistent for the machine
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","Machine") + ";$bin", "Machine")
curl.exe --version
