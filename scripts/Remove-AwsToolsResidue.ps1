<#
.SYNOPSIS
    Removes superseded and half-deleted AWS.Tools.* module folders left behind by an upgrade.

.DESCRIPTION
    DRY RUN BY DEFAULT. Prints the plan and changes nothing until you pass -Submit.

    Why half-deleted folders exist at all: Install-Module writes a new version alongside the old
    one, and the old one can only be deleted if nothing holds its files open. A PowerShell session
    that imported the module has its DLLs loaded into the process for the life of that process -
    .NET assemblies cannot be unloaded, and Remove-Module does not release them. So a cleanup run
    from a session that has ever touched AWS.Tools deletes the manifests, the .psm1 and the format
    files, and fails on every .dll. What is left is a HUSK: a version folder containing nothing but
    locked DLLs.

    A husk is invisible to Get-Module -ListAvailable (no manifest to read), so it does NOT affect a
    fresh session - which is why a new pwsh resolves the new version perfectly well while the old
    session that did the upgrade keeps failing on a format file that no longer exists. The husk is
    disk clutter, not a functional problem, but it will accumulate one copy per release.

    THE ORDER THAT MATTERS: close every other PowerShell session FIRST, then run this. Otherwise
    you simply make more husks. This script refuses to delete a folder whose files are locked and
    tells you so, rather than reporting partial success.

.PARAMETER Submit
    Actually delete. Without it, nothing is changed.

.PARAMETER Version
    The version to KEEP. Defaults to the highest version found on disk.

.PARAMETER IncludeWindowsPowerShell
    Also consider the Windows PowerShell 5.1 module roots (…\Documents\WindowsPowerShell\Modules
    and C:\Program Files\WindowsPowerShell\Modules). Off by default, because the 5.1 path is a
    separate question from the pwsh one and may be deliberately pinned.

.EXAMPLE
    .\Remove-AwsToolsResidue.ps1                   # show the plan
    .\Remove-AwsToolsResidue.ps1 -Submit           # apply it
#>
[CmdletBinding()]
param(
    [switch]$Submit,
    [string]$Version,
    [switch]$IncludeWindowsPowerShell
)

$ErrorActionPreference = 'Stop'

$roots = @("$env:USERPROFILE\Documents\PowerShell\Modules", "$env:ProgramFiles\PowerShell\Modules")
if ($IncludeWindowsPowerShell) {
    $roots += "$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
    $roots += "$env:ProgramFiles\WindowsPowerShell\Modules"
}

# Anything still running is a potential lock holder, and there is no cheap way to ask Windows which
# process holds which file without Sysinternals handle.exe. Naming the suspects is more useful than
# guessing: close them, then re-run.
$others = @(Get-Process -Name pwsh, powershell, powershell_ise -ErrorAction Ignore |
            Where-Object { $_.Id -ne $PID })
if ($others) {
    Write-Host 'Other PowerShell processes are running. Any of them that has imported AWS.Tools'  -ForegroundColor Yellow
    Write-Host 'holds its DLLs open and will defeat the delete. Close them before using -Submit:' -ForegroundColor Yellow
    $others | ForEach-Object { Write-Host ("   PID {0,-7} {1,-12} started {2}" -f $_.Id, $_.ProcessName, $_.StartTime) }
    Write-Host ''
}

# Enumerate on disk rather than via Get-Module -ListAvailable: husks have no manifest, so the
# module system cannot see them, and they are exactly what this script exists to remove.
$found = foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($module in Get-ChildItem $root -Directory -Filter 'AWS.Tools.*' -ErrorAction Ignore) {
        foreach ($dir in Get-ChildItem $module.FullName -Directory -ErrorAction Ignore) {
            $parsed = $null
            if (-not [version]::TryParse($dir.Name, [ref]$parsed)) { continue }
            $files = @(Get-ChildItem $dir.FullName -File -Recurse -ErrorAction Ignore)
            [pscustomobject]@{
                Module      = $module.Name
                Version     = $parsed
                Path        = $dir.FullName
                Root        = $root
                HasManifest = [bool](Test-Path (Join-Path $dir.FullName "$($module.Name).psd1"))
                FileCount   = $files.Count
                Files       = $files
            }
        }
    }
}
$found = @($found)

if (-not $found) { Write-Host 'No AWS.Tools.* module folders found.'; return }

if ($Version) { $keep = [version]$Version } else { $keep = ($found.Version | Sort-Object -Descending)[0] }
Write-Host "Keeping version : $keep"
Write-Host "Roots scanned   : $($roots.Count)$(if (-not $IncludeWindowsPowerShell) { '  (pwsh only - pass -IncludeWindowsPowerShell for the 5.1 paths)' })"
if (-not $Submit) { Write-Host 'DRY RUN - nothing will be changed. Re-run with -Submit to apply.' -ForegroundColor Yellow }
Write-Host ''

# A file that cannot be opened for exclusive write is locked. This is the same question the delete
# will ask, asked up front so the report is accurate before anything is touched.
function Test-Locked($file) {
    try { $s = [IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None'); $s.Close(); return $false }
    catch { return $true }
}

$toDelete = @()
foreach ($item in ($found | Sort-Object Module, Version)) {
    if ($item.Version -eq $keep) {
        $state = if ($item.HasManifest) { 'KEEP' } else { 'KEEP (no manifest - suspect!)' }
        Write-Host ("  {0,-38} {1,-9} {2}" -f $item.Module, $item.Version, $state) -ForegroundColor Green
        continue
    }
    $locked = @($item.Files | Where-Object { Test-Locked $_ })
    $kind   = if ($item.HasManifest) { 'SUPERSEDED' } else { 'HUSK' }
    if ($locked) {
        Write-Host ("  {0,-38} {1,-9} {2} - LOCKED ({3}/{4} files): {5}" -f
                    $item.Module, $item.Version, $kind, $locked.Count, $item.FileCount, $item.Path) -ForegroundColor Red
        continue
    }
    Write-Host ("  {0,-38} {1,-9} {2} - delete ({3} files): {4}" -f
                $item.Module, $item.Version, $kind, $item.FileCount, $item.Path) -ForegroundColor Cyan
    $toDelete += $item
}

$blocked = @($found | Where-Object { $_.Version -ne $keep }).Count - $toDelete.Count
Write-Host ''
Write-Host "Plan: delete $($toDelete.Count) folder(s)$(if ($blocked -gt 0) { ", $blocked BLOCKED by file locks" })."
if ($blocked -gt 0) {
    Write-Host 'Close the PowerShell sessions listed above and re-run. Deleting a locked folder' -ForegroundColor Yellow
    Write-Host 'partially is what created the husks in the first place, so this does not try.'   -ForegroundColor Yellow
}

if (-not $Submit) { Write-Host 'DRY RUN - re-run with -Submit to apply.' -ForegroundColor Yellow; return }

foreach ($item in $toDelete) {
    Write-Host "Removing $($item.Module) $($item.Version)"
    Remove-Item $item.Path -Recurse -Force -ErrorAction Continue
    # An empty <Module> folder left behind after its last version goes is harmless but untidy, and
    # it makes the next inventory misleading.
    $parent = Split-Path $item.Path -Parent
    if (-not (Get-ChildItem $parent -Force -ErrorAction Ignore)) { Remove-Item $parent -Force -ErrorAction Ignore }
}

Write-Host ''
Write-Host 'Remaining on disk:'
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem $root -Directory -Filter 'AWS.Tools.*' -ErrorAction Ignore | ForEach-Object {
        Get-ChildItem $_.FullName -Directory -ErrorAction Ignore | ForEach-Object {
            Write-Host ("   {0}" -f $_.FullName)
        }
    }
}
