<#
.SYNOPSIS
    Internalise a Chocolatey community package so the installer binary is embedded in the .nupkg
    instead of downloaded from a vendor CDN at install time, then optionally push it to the private
    'lansa' feed.

.DESCRIPTION
    Open-source Chocolatey has no 'choco download --internalize' (that is a Licensed/Business
    feature), so this does the equivalent manually:
      1. Downloads the community .nupkg for the given Id/Version.
      2. Extracts it.
      3. Finds the installer URL(s) in tools\chocolateyInstall.ps1 and downloads each into tools\.
      4. Rewrites those URL literals to point at the embedded local file.
      5. Repacks with 'choco pack' and (optionally) pushes to the private feed.

    Afterwards the bake installs entirely from the private feed with no vendor-CDN dependency:
        choco install <Id> --version <Version> --source lansa

    Motivation: bakes were hanging/slow because packages (e.g. FoxitReader) download a ~128 MB
    installer from Foxit's CDN at install time; URLs also rotate and break. See the team notes on
    "choco community source drift".

.LIMITATIONS
    Handles packages whose installer URLs are plain quoted string literals ending in a known
    installer extension (.exe/.msi/.msu/.zip/.7z) - covers FoxitReader, git, GoogleChrome, vscode,
    etc. Packages that build their URL dynamically (string concatenation / version interpolation)
    are reported and must be internalised by hand.

    AzDO Artifact feeds are immutable: to replace an existing version on 'lansa' with the
    internalised build, unlist/delete the old version first, or push under a new version and update
    the --version pin in the bake.

.EXAMPLE
    # Build only (review before pushing):
    .\Internalize-ChocoPackage.ps1 -Id FoxitReader -Version 2025.1.0.27937

.EXAMPLE
    # Build and push to the private feed:
    .\Internalize-ChocoPackage.ps1 -Id FoxitReader -Version 2025.1.0.27937 -Push
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Id,
    [Parameter()][string]$Version,   # omit / empty = resolve the latest community version
    [string]$CommunityFeed = 'https://community.chocolatey.org/api/v2/package',
    [string]$PushSource    = 'Lansa',
    [string]$ApiKey        = 'arbitrary',
    [string]$WorkDir       = (Join-Path $env:TEMP 'internalize-choco'),
    [string]$OutputDirectory,   # where to place the built .nupkg (default: a per-package temp folder)
    [string[]]$InstallerExtensions = @('.exe', '.msi', '.msu', '.zip', '.7z'),
    [switch]$Push
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }

# Download $Url into $ToolsDir, resolving the real file name from the Content-Disposition header,
# the final (redirected) URL, or a sensible default. Returns the saved file name. Handles
# extensionless download URLs (e.g. VS Code's '.../stable', Java's 'AutoDL?BundleId=...').
function Save-Installer($Url, $ToolsDir, $DefaultBase) {
    $req = [System.Net.HttpWebRequest]::Create($Url)
    $req.UserAgent = 'chocolatey command line'
    $req.AllowAutoRedirect = $true
    $resp = $req.GetResponse()
    try {
        $name = $null
        $cd = $resp.Headers['Content-Disposition']
        if ($cd -and ($cd -match 'filename\*?=(?:UTF-8'''')?"?([^";]+)"?')) { $name = [IO.Path]::GetFileName($Matches[1].Trim()) }
        if (-not $name) { $name = [IO.Path]::GetFileName($resp.ResponseUri.AbsolutePath) }
        if (-not $name -or ($name -notmatch '\.[A-Za-z0-9]{2,4}$')) { $name = "$DefaultBase.exe" }
        $dest = Join-Path $ToolsDir $name
        $in = $resp.GetResponseStream()
        $out = [IO.File]::Create($dest)
        try { $in.CopyTo($out) } finally { $out.Close(); $in.Close() }
        return $name
    } finally { $resp.Close() }
}

# Fix a common community-package bug: silentArgs defined with SINGLE quotes but containing $()
# subexpressions. In single quotes $(...) is NOT expanded, so e.g. an MSI log path
# '/l*v "$($env:TEMP)\...log"' is passed to msiexec literally and fails (exit 1622). Convert such
# single-quoted assignments to double-quoted so the subexpressions expand.
function Repair-SilentArgsExpansion($text) {
    return [regex]::Replace($text, "(silentArgs\s*=\s*)'([^']*)'", {
        $mm = $args[0]
        $inner = $mm.Groups[2].Value
        if ($inner -notmatch '\$\(') { return $mm.Value }   # no subexpression - already fine, leave as-is
        $inner = [regex]::Replace($inner, '(?<!`)"', '`"')   # escape bare quotes for a double-quoted string
        return $mm.Groups[1].Value + '"' + $inner + '"'
    })
}

# Resolve the latest community version when -Version is omitted/empty
if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Step "Resolving latest version of $Id from the community feed"
    $found = & choco search $Id --exact --limit-output --source 'https://community.chocolatey.org/api/v2/'
    if ($LASTEXITCODE -ne 0) { throw "choco search failed resolving latest version for '$Id' (exit $LASTEXITCODE)." }
    $line = @($found | Where-Object { $_ -match '\|' })[0]
    if (-not $line) { throw "Could not resolve a latest version for '$Id' from the community feed." }
    $Version = ($line -split '\|', 2)[1].Trim()
    Write-Host "      latest = $Version"
}

# Fresh work area for this package/version
$pkgWork = Join-Path $WorkDir "$Id.$Version"
if (Test-Path $pkgWork) { Remove-Item $pkgWork -Recurse -Force }
$extractDir = Join-Path $pkgWork 'pkg'
New-Item -ItemType Directory -Path $extractDir -Force | Out-Null

Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue

# 1. Download the community .nupkg
$nupkg = Join-Path $pkgWork "$Id.$Version.nupkg"
$downloadUrl = "$CommunityFeed/$Id/$Version"
Write-Step "Downloading community package: $downloadUrl"
Invoke-WebRequest -Uri $downloadUrl -OutFile $nupkg -UseBasicParsing

# 2. Extract (.nupkg is a zip)
Write-Step "Extracting to $extractDir"
[System.IO.Compression.ZipFile]::ExtractToDirectory($nupkg, $extractDir)

# Drop NuGet-internal artefacts so 'choco pack' rebuilds them cleanly
foreach ($junk in '_rels', 'package', '[Content_Types].xml') {
    $p = Join-Path $extractDir $junk
    if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force }
}

# Locate the install script
$installScript = Get-ChildItem -Path $extractDir -Recurse -Filter 'chocolateyInstall.ps1' | Select-Object -First 1
# Analyse the install script only if there is one. Meta/extension packages (git, vscode,
# chocolatey-core.extension) have no chocolateyInstall.ps1 - nothing to embed, so they are
# re-hosted unchanged and the dependency chain still resolves from the private feed.
$installerUrls = @()
$embeddedFiles = @()
if (-not $installScript) {
    Write-Warning "No chocolateyInstall.ps1 in $Id.$Version - re-hosting package unchanged (meta/extension package, nothing to embed)."
} else {
    $toolsDir = Split-Path -Parent $installScript.FullName
    $content = Get-Content -LiteralPath $installScript.FullName -Raw
    $installScriptOriginal = $content

    # Fix single-quoted silentArgs whose $() would not expand (e.g. a literal '$($env:TEMP)' log path).
    $content = Repair-SilentArgsExpansion $content

    # Detect installer URLs: quoted http(s) literals that either end in a known installer extension
    # OR are assigned to a url-like key/param (url, url32, url64, url64bit). The key check catches
    # extensionless redirect URLs (VS Code '.../stable', Java 'AutoDL?BundleId=...').
    $urlArch = [ordered]@{}   # url -> '64' | '32' | ''  (architecture inferred from the assigning key)
    foreach ($m in [regex]::Matches($content, '([''"])(https?://[^''"]+)\1')) {
        $u = $m.Groups[2].Value
        $before = $content.Substring([Math]::Max(0, $m.Index - 24), [Math]::Min(24, $m.Index))
        $bare = $u.Split('?')[0].ToLower()
        $byExt = [bool]@($InstallerExtensions | Where-Object { $bare.EndsWith($_) })
        $arch = $null
        if ($before -match '(?i)(^|[^a-z])url(64bit|64|32)?\s*=?\s*$') {
            $suffix = $Matches[2]
            if ($suffix -match '64') { $arch = '64' } elseif ($suffix -eq '32') { $arch = '32' } else { $arch = '' }
        }
        if ($byExt -or ($null -ne $arch)) {
            if ($null -eq $arch) { $arch = '' }
            $urlArch[$u] = $arch
        }
    }

    # 64-bit only: we support 64-bit Windows exclusively, and bundling a 32-bit installer as well can
    # push a package past AzDO's 500 MB feed limit (that was FoxitReader at ~690 MB). When a 64-bit
    # installer is present, skip the 32-bit / bare-url ones - do not download or embed them. Their
    # original (CDN) URL stays in the script but is never used on a 64-bit OS.
    $has64 = ($urlArch.Values -contains '64')
    $installerUrls = @()
    foreach ($u in $urlArch.Keys) {
        if ($has64 -and $urlArch[$u] -ne '64') {
            Write-Host "      (64-bit only: skipping 32-bit installer $u)"
            continue
        }
        $installerUrls += $u
    }
    $installerUrls = @($installerUrls)

    if (-not $installerUrls) {
        Write-Warning "No downloadable installer URL found in $($installScript.Name) - not embedding an installer (meta/extension package, or a dynamically-built URL)."
    } else {
        # Download each installer into tools\ and rewrite the URL literal to a local path expression
        $installerIndex = 0
        foreach ($url in $installerUrls) {
            $installerIndex++
            Write-Step "Downloading installer: $url"
            $fileName = Save-Installer $url $toolsDir "$Id-$installerIndex"
            $embeddedFiles += $fileName
            Write-Host "      -> tools\$fileName"

            # Replace the quoted URL literal (single OR double quoted) with a local-path expression.
            # Uniquely named var so it never collides with an existing $toolsDir in the script.
            # Use literal String.Replace, NOT -replace: a regex replacement interprets the '$_' in
            # "$__lansaToolsDir" as the entire input string and corrupts the whole script.
            $replacement = '"$__lansaToolsDir\' + $fileName + '"'
            $content = $content.Replace("'" + $url + "'", $replacement)
            $content = $content.Replace('"' + $url + '"', $replacement)
        }

        # Define the tools dir at the top so the replacements resolve at install time.
        $content = '$__lansaToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition' + [Environment]::NewLine + $content
    }

    # Write the install script back if the silentArgs repair and/or the URL rewrite changed it.
    if ($content -ne $installScriptOriginal) {
        Set-Content -LiteralPath $installScript.FullName -Value $content -Encoding UTF8
        Write-Step "Updated $($installScript.Name)"
    }
}

# Repair the uninstall script's silentArgs too - community packages (e.g. FoxitReader) ship a
# chocolateyUninstall.ps1 whose single-quoted silentArgs holds an unexpanded '$($env:TEMP)\...' MSI
# log path, so uninstall fails with exit 1622. The bake never uninstalls, but this keeps published
# packages cleanly removable.
$uninstallScript = Get-ChildItem -Path $extractDir -Recurse -Filter 'chocolateyUninstall.ps1' | Select-Object -First 1
if ($uninstallScript) {
    $uc = Get-Content -LiteralPath $uninstallScript.FullName -Raw
    $ucFixed = Repair-SilentArgsExpansion $uc
    if ($ucFixed -ne $uc) {
        Set-Content -LiteralPath $uninstallScript.FullName -Value $ucFixed -Encoding UTF8
        Write-Step "Repaired silentArgs in $($uninstallScript.Name)"
    }
}

# 5. Repack
$nuspec = Get-ChildItem -Path $extractDir -Filter '*.nuspec' | Select-Object -First 1
if (-not $nuspec) { throw 'No .nuspec found to repack.' }
$outDir = if ($OutputDirectory) { $OutputDirectory } else { Join-Path $pkgWork 'out' }
New-Item -ItemType Directory -Path $outDir -Force | Out-Null
Write-Step 'Packing internalised nupkg'
choco pack $nuspec.FullName --outputdirectory $outDir | Write-Host
if ($LASTEXITCODE -ne 0) { throw "choco pack failed (exit $LASTEXITCODE)." }
# Newest .nupkg = the one just packed (the output folder may be shared across packages)
$newNupkg = Get-ChildItem -Path $outDir -Filter '*.nupkg' | Sort-Object LastWriteTime -Descending | Select-Object -First 1

# Verify the embedded installer(s) actually made it into the package (guards against an explicit <files> list)
if ($embeddedFiles) {
    $zip = [System.IO.Compression.ZipFile]::OpenRead($newNupkg.FullName)
    try { $entries = @($zip.Entries.FullName) } finally { $zip.Dispose() }
    foreach ($fileName in $embeddedFiles) {
        if (-not ($entries | Where-Object { $_ -like "*tools/$fileName" })) {
            throw "Packed nupkg is missing tools\$fileName. The .nuspec likely has an explicit <files> list - add '<file src=`"tools\**`" target=`"tools`" />' to it and re-run."
        }
    }
}
Write-Host "Package ready: $($newNupkg.FullName)" -ForegroundColor Green

# 6. Optionally push
if ($Push) {
    Write-Step "Pushing to '$PushSource' via nuget"
    & nuget push $newNupkg.FullName -Source $PushSource -ApiKey $ApiKey | Write-Host
    if ($LASTEXITCODE -ne 0) {
        throw "nuget push failed (exit $LASTEXITCODE). If this version already exists on the feed, permanently DELETE it in Azure DevOps (Artifacts -> package -> the version -> Delete; a plain unlist is NOT enough to re-push the same version), or push a newer version."
    }
    Write-Host "Pushed $($newNupkg.Name) to $PushSource" -ForegroundColor Green
} else {
    Write-Host 'Not pushed. Review it, then push with:' -ForegroundColor Yellow
    Write-Host "    nuget push `"$($newNupkg.FullName)`" -Source $PushSource -ApiKey $ApiKey"
}
