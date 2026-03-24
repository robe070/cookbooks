Write-Host("curl.exe is required for licensing and other operations, but is not included in the base Windows image. Download and install it from the official source.")
$curlZip = "C:\temp\curl.zip"
$curlDir = "C:\tools\curl"
New-Item -ItemType Directory -Force -Path (Split-Path $curlZip) | Out-Null
Invoke-WebRequest -Uri "https://curl.se/windows/dl-8.6.0_3/curl-8.6.0_3-win64-mingw.zip" -OutFile $curlZip
Expand-Archive -Path $curlZip -DestinationPath $curlDir -Force

# Add to PATH for current session
$bin = Get-ChildItem -Path $curlDir -Directory | Select-Object -First 1 | ForEach-Object { Join-Path $_.FullName "bin" }
$env:Path = "$env:Path;$bin"

# Optional: make it persistent for the machine
[Environment]::SetEnvironmentVariable("Path", [Environment]::GetEnvironmentVariable("Path","Machine") + ";$bin", "Machine")
curl.exe --version