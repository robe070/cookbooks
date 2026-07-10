<#
.SYNOPSIS
    Internalise and publish the vetted Chocolatey package set to the private 'Lansa' Azure DevOps
    feed, with each installer binary embedded in the package (no vendor-CDN dependency at install
    time). Supersedes choco-push.ps1.

.DESCRIPTION
    For each package it calls Internalize-ChocoPackage.ps1, which downloads the community package,
    embeds the installer into tools\ (or re-hosts as-is for meta/extension packages), repacks, and
    pushes to the Lansa feed via nuget. Packages with no Version are published at the latest
    community version.

    Prerequisites (one-time):
      - nuget.exe on PATH, and the 'Lansa' source configured with a PAT (Packaging: Read & write).
        See scripts\nuget.config for the feed URL; store the PAT in your USER nuget config, e.g.:
        nuget sources add -Name Lansa -Source <v3-index-url> -Username lansa -Password <PAT>
      - Chocolatey installed (used for pack + latest-version resolution).

    Notes:
      - Run failures are reported per-package and do not stop the run.
      - AzDO feed versions are IMMUTABLE and a DELETED version can NEVER be re-pushed (409). So this
        script never deletes/overwrites - it publishes new versions and -SkipDuplicate skips a version
        already on the feed. To replace content, publish a NEW (higher) version; the bake installs the
        latest, so the newer one wins.

.PARAMETER PackOnly
    Build/embed each package but do not push (review the .nupkg files first).

.PARAMETER Only
    Limit the run to these package ids (default: all).

.PARAMETER PushOnly
    Publish the .nupkgs a previous -PackOnly run left in -OutputDirectory, without rebuilding.

.PARAMETER OutputDirectory
    Staging folder shared between -PackOnly and -PushOnly (default: %TEMP%\lansa-packages).

.EXAMPLE
    .\publish-lansa-packages.ps1                 # internalise + push all, latest versions

.EXAMPLE
    # Two-phase: build, test locally, then publish.
    .\publish-lansa-packages.ps1 -PackOnly
    #   ... test, e.g.:  choco install FoxitReader --source "$env:TEMP\lansa-packages" -y
    .\publish-lansa-packages.ps1 -PushOnly

.EXAMPLE
    .\publish-lansa-packages.ps1 -Only FoxitReader,git.install
#>
[CmdletBinding()]
param(
    [switch]$PackOnly,
    [switch]$PushOnly,
    [string[]]$Only,
    [string]$OutputDirectory = (Join-Path ([IO.Path]::GetTempPath()) 'lansa-packages')
)

if ($PackOnly -and $PushOnly) { throw '-PackOnly and -PushOnly are mutually exclusive.' }

# The vetted set (from the old choco-push.ps1). Omit Version = publish the latest community version.
# Pin a version only when you need reproducibility, e.g. @{ Id='FoxitReader'; Version='2024.4.0.27683' }
$packages = @(
    @{ Id = 'git.install' }
    @{ Id = 'git' }
    @{ Id = 'GoogleChrome' }
    @{ Id = 'jre8' }
    @{ Id = 'jdk8' }
    @{ Id = 'vscode.install' }
    @{ Id = 'vscode' }
    @{ Id = 'kdiff3' }
    @{ Id = 'DotNet4.5.2' }
    @{ Id = 'chocolatey-core.extension' }
    @{ Id = 'chocolatey-compatibility.extension' }      # dependency of newer git.install; must be on the feed for -s=lansa resolution
    @{ Id = 'FoxitReader'; Version = '2025.1.0.27937' } # Pinned to reduce size so that pushing the package is quicker
)

if ($Only) {
    $packages = $packages | Where-Object { $Only -contains $_.Id }
    if (-not $packages) { throw "None of -Only [$($Only -join ', ')] matched the package list." }
}

$internalizer = Join-Path $PSScriptRoot 'Internalize-ChocoPackage.ps1'
if (-not (Test-Path $internalizer)) { throw "Cannot find Internalize-ChocoPackage.ps1 next to this script." }

$PushSource = 'Lansa'
$ApiKey     = 'arbitrary'   # AzDO ignores the value; auth is via your PAT in the nuget config

# Run from this folder so the 'Lansa' nuget source in scripts\nuget.config resolves for the push.
Push-Location $PSScriptRoot
try {
    if ($PushOnly) {
        # Publish the .nupkgs a previous -PackOnly run left in the staging folder.
        if (-not (Test-Path $OutputDirectory)) { throw "Staging folder '$OutputDirectory' not found. Run with -PackOnly first." }
        $results = foreach ($p in $packages) {
            Write-Host "`n=== push $($p.Id) ===" -ForegroundColor Magenta
            # Match '<id>.<digit>...' so e.g. 'git' does not also grab 'git.install'.
            $nupkg = Get-ChildItem $OutputDirectory -Filter "$($p.Id).*.nupkg" |
                Where-Object { $_.Name -match ('^' + [regex]::Escape($p.Id) + '\.\d') } |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $nupkg) {
                Write-Warning "No packed .nupkg for '$($p.Id)' in $OutputDirectory - run -PackOnly first."
                [pscustomobject]@{ Package = $p.Id; Result = 'FAILED: no packed .nupkg found' }
                continue
            }
            try {
                # AzDO versions are immutable AND a deleted version can never be re-pushed (409), so we
                # never delete before pushing - we publish new versions and -SkipDuplicate makes a
                # version already on the feed a no-op. Retry with backoff for AzDO's transient 503s.
                $maxAttempts = 4
                for ($attempt = 1; $attempt -le $maxAttempts; $attempt++) {
                    & nuget push $nupkg.FullName -Source $PushSource -ApiKey $ApiKey -Timeout 1800 -SkipDuplicate | Write-Host
                    if ($LASTEXITCODE -eq 0) { break }
                    if ($attempt -eq $maxAttempts) { throw "nuget push failed after $maxAttempts attempts (last exit $LASTEXITCODE)" }
                    $delay = 30 * $attempt
                    Write-Warning "  push attempt $attempt/$maxAttempts failed (exit $LASTEXITCODE) - retrying in ${delay}s (AzDO 503s are usually transient)"
                    Start-Sleep -Seconds $delay
                }
                [pscustomobject]@{ Package = $p.Id; Result = 'pushed' }
            } catch {
                Write-Warning "FAILED: $($p.Id) - $($_.Exception.Message)"
                [pscustomobject]@{ Package = $p.Id; Result = "FAILED: $($_.Exception.Message)" }
            }
        }
    } else {
        # Internalise each package into the staging folder (and push unless -PackOnly).
        if ($PackOnly -and -not $Only -and (Test-Path $OutputDirectory)) {
            # Full -PackOnly run: start clean so a later -PushOnly publishes exactly this set.
            # (With -Only we keep the folder and just add/replace those packages.)
            Remove-Item (Join-Path $OutputDirectory '*.nupkg') -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
        $results = foreach ($p in $packages) {
            $verLabel = if ($p.Version) { $p.Version } else { '(latest)' }
            Write-Host "`n=== $($p.Id) $verLabel ===" -ForegroundColor Magenta
            try {
                $callArgs = @{ Id = $p.Id; OutputDirectory = $OutputDirectory }
                if ($p.Version) { $callArgs.Version = $p.Version }
                if (-not $PackOnly) { $callArgs.Push = $true }
                & $internalizer @callArgs
                [pscustomobject]@{ Package = $p.Id; Result = if ($PackOnly) { 'packed' } else { 'pushed' } }
            } catch {
                Write-Warning "FAILED: $($p.Id) - $($_.Exception.Message)"
                [pscustomobject]@{ Package = $p.Id; Result = "FAILED: $($_.Exception.Message)" }
            }
        }
    }
} finally {
    Pop-Location
}

Write-Host "`n===== Summary =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize

$failed = @($results | Where-Object { $_.Result -like 'FAILED*' })
if ($failed) {
    Write-Warning "$($failed.Count) package(s) failed. If a push says the version already exists, permanently delete it in Azure DevOps (Artifacts -> Lansa -> package -> the version -> Delete; unlist is not enough), then re-run with -Only <ids>."
    exit 1
}

if ($PackOnly) {
    Write-Host "All $($results.Count) package(s) packed to: $OutputDirectory" -ForegroundColor Green
    Write-Host "Test them, then publish with:  .\publish-lansa-packages.ps1 -PushOnly" -ForegroundColor Green
} else {
    Write-Host "All $($results.Count) package(s) published to Lansa." -ForegroundColor Green
}
