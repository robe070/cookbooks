<#
.SYNOPSIS
    Brings this machine's AWS.Tools.* modules to the same state 'create agents.yml' now puts on
    the build agents: the full module set, all on ONE current version, with older copies removed.

.DESCRIPTION
    DRY RUN BY DEFAULT, per the convention of the other tooling scripts in this repo. It prints
    the plan and changes nothing until you pass -Submit.

    Why the whole set lands on one version: every AWS.Tools.<Service> manifest declares a
    RequiredModules dependency on the EXACTLY matching AWS.Tools.Common, and AWS ships the family
    in lockstep. A machine holding 5.0.300 and 5.0.301 of different modules is one import away
    from a version-mismatch failure, which is why superseded copies are removed rather than left.

    The target version is resolved ONCE from AWS.Tools.Common and applied to every module with
    -RequiredVersion, rather than asking each module for 'latest' independently - which would
    skew the set if AWS published a release part way through.

.PARAMETER Submit
    Actually install and remove. Without it, nothing is changed.

.PARAMETER Scope
    CurrentUser (default) matches where this machine's existing AWS.Tools modules already live
    (…\Documents\PowerShell\Modules). Note that path is pwsh-only - Windows PowerShell 5.1 does
    not read it. Use AllUsers if you need both shells to see them, as the agents do.

.PARAMETER Version
    Override the target version. Defaults to the current release on PSGallery.

.EXAMPLE
    .\Sync-AwsTools.ps1                  # show the plan
    .\Sync-AwsTools.ps1 -Submit          # apply it
#>
[CmdletBinding()]
param(
    [switch]$Submit,
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope = 'CurrentUser',
    [string]$Version
)

$ErrorActionPreference = 'Stop'

# Kept deliberately identical to the list in 'create agents.yml' - if you add one there, add it
# here. Derived from the cmdlets the cookbooks and db-regression scripts actually call.
$awsToolsModules = @(
    'AWS.Tools.Common'                    # Set-DefaultAWSRegion, credentials
    'AWS.Tools.EC2'
    'AWS.Tools.CloudFormation'
    'AWS.Tools.RDS'
    'AWS.Tools.SecretsManager'            # Get-SECSecretValue
    'AWS.Tools.SimpleSystemsManagement'   # Send-SSMCommand
    'AWS.Tools.S3'
    'AWS.Tools.AutoScaling'               # Get-ASTag, Suspend-ASProcess
    'AWS.Tools.ElasticLoadBalancing'      # classic ELB, NOT ELBv2
    'AWS.Tools.SimpleNotificationService' # Publish-SNSMessage
    'AWS.Tools.SecurityToken'             # Get-STSSessionToken
    'AWS.Tools.ECR'                       # Get-ECRLoginCommand
)

if ($Version) {
    $target = [version]$Version
    Write-Host "Target version (from -Version): $target"
} else {
    $target = [version](Find-Module -Name AWS.Tools.Common -Repository PSGallery).Version
    Write-Host "Target version (latest on PSGallery): $target"
}

if (-not $Submit) {
    Write-Host 'DRY RUN - nothing will be changed. Re-run with -Submit to apply.' -ForegroundColor Yellow
}
Write-Host "Scope: $Scope"
Write-Host ''

# The monolithic module cannot coexist with the modular set - both export Get-EC2Instance and
# friends, so auto-loading would resolve to whichever module path came first.
$legacy = @(Get-Module -ListAvailable -Name AWSPowerShell, AWSPowerShell.NetCore)
if ($legacy) {
    Write-Host 'Monolithic AWSPowerShell found - it conflicts with AWS.Tools and must go:' -ForegroundColor Yellow
    $legacy | ForEach-Object { Write-Host "  $($_.Name) $($_.Version)  $($_.ModuleBase)" }
    if ($Submit) {
        foreach ($m in $legacy) {
            Uninstall-Module -Name $m.Name -AllVersions -Force -ErrorAction Ignore
            if (Test-Path $m.ModuleBase) { Remove-Item $m.ModuleBase -Recurse -Force -ErrorAction Ignore }
        }
        Write-Host '  removed.' -ForegroundColor Green
    }
    Write-Host ''
}

$toInstall = @()
$toRemove  = @()

foreach ($name in $awsToolsModules) {
    $installed = @(Get-Module -ListAvailable -Name $name)
    $atTarget  = $installed | Where-Object { $_.Version -eq $target }
    $others    = $installed | Where-Object { $_.Version -ne $target }

    if ($atTarget) {
        Write-Host ("  {0,-38} {1}  OK" -f $name, $target) -ForegroundColor Green
    } else {
        $have = if ($installed) { ($installed.Version | Sort-Object | ForEach-Object { $_.ToString() }) -join ', ' } else { 'absent' }
        Write-Host ("  {0,-38} {1}  INSTALL  (have: {2})" -f $name, $target, $have) -ForegroundColor Cyan
        $toInstall += $name
    }
    foreach ($o in $others) {
        Write-Host ("  {0,-38} {1}  REMOVE   {2}" -f $name, $o.Version, $o.ModuleBase) -ForegroundColor Yellow
        $toRemove += $o
    }
}

Write-Host ''
Write-Host "Plan: install $($toInstall.Count), remove $($toRemove.Count) superseded."

if (-not $Submit) {
    Write-Host 'DRY RUN - re-run with -Submit to apply.' -ForegroundColor Yellow
    return
}

# Install first, remove second: if an install fails, the machine still has a working older set
# rather than nothing at all.
foreach ($name in $toInstall) {
    Write-Host "Installing $name $target"
    Install-Module -Name $name -RequiredVersion $target -Scope $Scope -Force -AllowClobber
}

# A .NET assembly loaded by a PowerShell session cannot be unloaded for the life of that process -
# Remove-Module does not release it. So deleting a superseded version from a session that ever
# imported it removes the manifests, the .psm1 and the format files and fails on every .dll,
# leaving a HUSK: a version folder of nothing but locked DLLs. The husk is invisible to
# Get-Module -ListAvailable so fresh sessions are fine, but the session that did the upgrade then
# keeps failing on a format file that no longer exists. Check first and skip rather than half-delete.
function Test-FolderLocked($path) {
    foreach ($file in Get-ChildItem $path -File -Recurse -ErrorAction Ignore) {
        try { $s = [IO.File]::Open($file.FullName, 'Open', 'ReadWrite', 'None'); $s.Close() }
        catch { return $true }
    }
    return $false
}

$skipped = @()
foreach ($m in $toRemove) {
    if (Test-FolderLocked $m.ModuleBase) {
        Write-Host "SKIPPING $($m.Name) $($m.Version) - files are locked by a running process" -ForegroundColor Yellow
        $skipped += $m
        continue
    }
    Write-Host "Removing $($m.Name) $($m.Version)"
    # Remove-Item, not Uninstall-Module: a module installed under a different scope or by hand
    # has no PowerShellGet metadata for Uninstall-Module to find.
    Remove-Item $m.ModuleBase -Recurse -Force -ErrorAction Continue
}

if ($skipped) {
    Write-Host ''
    Write-Host "$($skipped.Count) superseded version(s) could not be removed. Close every other" -ForegroundColor Yellow
    Write-Host 'PowerShell session (including this one - they are locked by whoever imported them)' -ForegroundColor Yellow
    Write-Host 'and run Remove-AwsToolsResidue.ps1 from a fresh shell.'                            -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'AWS.Tools now installed:'
Get-Module -ListAvailable -Name AWS.Tools.* |
    Sort-Object Name, Version | Format-Table Name, Version, ModuleBase -AutoSize

# Same probe the pipeline runs, for the same reason: auto-loading is how every script resolves
# these, and a child process is the only honest way to test it from inside a session that may
# already have imported something.
$probes = @('Set-DefaultAWSRegion', 'Get-EC2Instance', 'Get-CFNStack', 'Get-RDSDBInstance',
            'Get-SECSecretValue', 'Send-SSMCommand', 'Write-S3Object', 'Get-ASTag',
            'Get-ELBInstanceHealth')
$list = ($probes | ForEach-Object { "'$_'" }) -join ','
$cmd  = "@($list) | Where-Object { -not (Get-Command `$_ -ErrorAction Ignore) }"
$missing = @(& (Get-Process -Id $PID).Path -NoProfile -Command $cmd)
if ($missing) {
    Write-Host "STILL MISSING: $($missing -join ', ')" -ForegroundColor Red
} else {
    Write-Host 'All AWS cmdlets auto-load in a fresh session.' -ForegroundColor Green
}
