<#
.SYNOPSIS
    Rewrites the plan-listing `description` for the LANSA Scalable License offer's
    LIVE plans so they satisfy Marketplace certification 100.1.3.4 (Plan Length and
    Quality). Dry-run by default: writes current-vs-desired JSON for diffing and a
    ready-to-send configure payload, but does NOT write to Partner Center unless you
    pass -Submit.

.DESCRIPTION
    Certification 100.1.3.4 failed because each plan description was just a one-line
    restatement of the plan name (e.g. "LANSA Version 16 GA on Microsoft Windows
    Server 2025 Datacenter"). MS wants a complete description that conveys the value
    proposition, business audience, and target industry.

    This script applies a shared, value-proposition base description (plain text --
    HTML is NOT rendered in plan descriptions) to every live plan, then appends a
    single sentence naming that plan's specific LANSA + Windows Server configuration
    so each plan stays distinct.

    SCOPE: only the LIVE plans are updated -- selected as displayRank <= -MaxDisplayRank
    (default 12) AND not lifecycleState 'deprecated'. The deprecated plans (ranks 13+)
    are intentionally left alone.

    The Product Ingestion API is declarative: submitting the plan-listing resource with
    a new description replaces it in place (draft only; nothing goes live until you
    publish in Partner Center).

    WORKFLOW
      1. Run with no -Submit  -> produces <out>-current.json, <out>-desired.json,
         and <out>-configure-payload.json. Diff the first two.
      2. Happy with the diff  -> re-run with -Submit (+ auth) to POST to configure
         (updates DRAFT only).

.PARAMETER TemplateFile
    Path to the exported resource-tree JSON (from Export-MarketplaceOffer.ps1).

.PARAMETER MaxDisplayRank
    Update plans whose displayRank is <= this value (default 12 == the live plans).

.PARAMETER BaseDescription
    Shared plain-text description applied to every targeted plan. A per-plan sentence
    ("This plan delivers <plan name>.") is appended automatically. Override to tweak
    the wording without editing the script.

.PARAMETER OutPrefix
    Path prefix for output files. Default .\plan-descriptions

.PARAMETER Submit
    Actually POST the configure payload to Partner Center (updates draft). Requires auth.

.PARAMETER TenantId / .PARAMETER ClientId / .PARAMETER ClientSecret
    App-only (client-credentials) auth for -Submit. The Entra app must be associated in
    Partner Center with the Manager role (see docs/marketplace-ingestion-api.md).

.EXAMPLE
    # Dry run: produce diff + payload, write nothing to Partner Center
    .\Update-PlanDescriptions.ps1 -TemplateFile .\product-9c420de5-...-draft.json

.EXAMPLE
    # After reviewing the diff, submit to draft
    .\Update-PlanDescriptions.ps1 -TemplateFile .\product-9c420de5-...-draft.json `
        -Submit -TenantId $t -ClientId $c -ClientSecret $s
#>
[CmdletBinding()]
param(
    [string] $TemplateFile,

    # Diagnostics only: fetch detailed per-resource errors for a prior configure jobID
    # and exit. Requires auth. Does not build or submit anything.
    [string] $StatusJobId,

    [int] $MaxDisplayRank = 12,

    [string] $BaseDescription = @'
LANSA is a low-code platform for building and running enterprise business applications. This plan provides a pre-configured Windows Server image, deployed via an Azure Resource Manager template, that stands up a complete, production-ready LANSA runtime stack on Azure - including a load balancer, one or more web servers, and an Azure SQL database.

The stack is highly available and fault tolerant, and is auto-installing, auto-upgrading, auto-patching, auto-scaling, and kept current with automatic Windows Updates - so IT teams can run business-critical LANSA web, mobile, and desktop applications with minimal operational overhead. Developers deploy applications to this environment from any Visual LANSA IDE via a generated MSI.

Who it's for: enterprise IT departments, ISVs, and application teams - particularly organizations modernizing and extending existing IBM i (AS/400) and Windows business systems across industries such as manufacturing, distribution, retail, insurance, and financial services.

The Usage Instructions and Azure Deployment Tutorial in the Overview give a step-by-step guide to deploying the stack. By default the template creates one B2_ms and one B4_ms Standard instance and one Azure SQL Database Standard S2 instance.
'@,

    [string] $OutPrefix = '.\plan-descriptions',

    # Endpoint $version for the configure API. Acts as a MAX schema-version ceiling for
    # parsing the request; must be >= the resource schema versions in the payload. The
    # plan-listing resources keep their own (older) $schema from the export -- see below.
    [string] $ConfigureVersion = '2026-04-01-preview1',

    [switch] $Submit,

    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$GraphBase = 'https://graph.microsoft.com/rp/product-ingestion'
$CfgSchema = 'https://schema.mp.microsoft.com/schema/configure/2022-03-01-preview2'

function Get-IngestionToken {
    if (-not ($TenantId -and $ClientId -and $ClientSecret)) { throw "Auth requires -TenantId/-ClientId/-ClientSecret." }
    $resp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $ClientSecret; scope = 'https://graph.microsoft.com/.default' }
    return $resp.access_token
}

# Print configure errors from a /status response. The real per-resource reasons live in
# errors[].details[] (the top-level message is just "Invalid resource"); the
# configure/<job> DETAIL endpoint 404s for failed jobs, so we never call it.
function Write-ConfigureErrors($status) {
    foreach ($e in $status.errors) {
        $rid = if ($e.PSObject.Properties.Name -contains 'resourceId') { "  [$($e.resourceId)]" } else { '' }
        Write-Host "  - $($e.message)$rid" -ForegroundColor Red
        if ($e.PSObject.Properties.Name -contains 'details' -and $e.details) {
            foreach ($d in $e.details) { Write-Host "      * $($d.message)" -ForegroundColor DarkYellow }
        }
    }
}

# --- Diagnostics-only: dump detailed status for a prior job and exit --------
if ($StatusJobId) {
    $headers = @{ Authorization = "Bearer $(Get-IngestionToken)" }
    Write-Host "Status for job $StatusJobId :" -ForegroundColor Cyan
    $status = Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "$GraphBase/configure/${StatusJobId}/status?`$version=$ConfigureVersion"
    Write-Host "  $($status.jobStatus) / $($status.jobResult)"
    if ($status.jobResult -ne 'succeeded') { Write-ConfigureErrors $status }
    return
}

# --- Load the exported tree ------------------------------------------------
if (-not $TemplateFile) { throw "Provide -TemplateFile (or -StatusJobId for diagnostics)." }
if (-not (Test-Path $TemplateFile)) { throw "Template file not found: $TemplateFile" }
$tree = Get-Content -Raw -Path $TemplateFile | ConvertFrom-Json
$resources = $tree.resources

function Get-ResType($r) { ($r.'$schema' -split '/schema/')[-1] -replace '/.*$', '' }
function Test-Prop($o, $n) { $o.PSObject.Properties.Name -contains $n }

# Deep-clone helper (round-trip through JSON so nested objects detach cleanly)
function Copy-Json($obj) { $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json }

# Index the plan resources by durable id: capture displayRank + lifecycleState so we can
# pick only the live, top-ranked plans.
$planInfo = @{}
foreach ($r in $resources) {
    if ((Get-ResType $r) -ne 'plan') { continue }
    $rank = if (Test-Prop $r 'displayRank') { [int]$r.displayRank } else { [int]::MaxValue }
    $life = if (Test-Prop $r 'lifecycleState') { $r.lifecycleState } else { '' }
    $planInfo[$r.id] = [pscustomobject]@{ displayRank = $rank; lifecycleState = $life }
}

# --- Select target plan-listings -------------------------------------------
# Live plans only: displayRank <= MaxDisplayRank AND not deprecated.
$targets = @()
foreach ($r in $resources) {
    if ((Get-ResType $r) -ne 'plan-listing') { continue }
    $planId = $r.plan
    if (-not $planInfo.ContainsKey($planId)) {
        Write-Warning "plan-listing $($r.id) references unknown plan $planId - skipped."
        continue
    }
    $info = $planInfo[$planId]
    if ($info.lifecycleState -eq 'deprecated') { continue }
    if ($info.displayRank -gt $MaxDisplayRank) { continue }
    $targets += [pscustomobject]@{ rank = $info.displayRank; listing = $r }
}
$targets = $targets | Sort-Object rank

if (-not $targets) { throw "No live plans found with displayRank <= $MaxDisplayRank." }
Write-Host "Targeting $($targets.Count) live plan(s) (displayRank 1..$MaxDisplayRank):" -ForegroundColor Cyan

# --- Build desired plan-listings -------------------------------------------
$baseTrim   = $BaseDescription.TrimEnd()
$currentSet = @()
$desiredSet = @()

foreach ($t in $targets) {
    $cur  = $t.listing
    $name = $cur.name
    $newDescription = "$baseTrim`n`nThis plan delivers $name."

    $desired = Copy-Json $cur
    # Keep the resource's OWN $schema from the export (plan-listing/2022-03-01-preview3).
    # Unlike tech-config, the WRITE path rejects the newer plan-listing versions the
    # resources-index advertises -- see docs/marketplace-ingestion-api.md (cloning rule).
    $desired | Add-Member -NotePropertyName description -NotePropertyValue $newDescription -Force

    $currentSet += $cur
    $desiredSet += $desired

    Write-Host ("  #{0,-2} {1}" -f $t.rank, $name) -ForegroundColor Green
}

# --- Emit dry-run artifacts ------------------------------------------------
$curFile = "$OutPrefix-current.json"
$desFile = "$OutPrefix-desired.json"
$payFile = "$OutPrefix-configure-payload.json"

$currentSet | ConvertTo-Json -Depth 100 | Set-Content -Path $curFile -Encoding UTF8
$desiredSet | ConvertTo-Json -Depth 100 | Set-Content -Path $desFile -Encoding UTF8

# The configure API identifies a plan-scoped resource by its product+plan refs; echoing
# back the server-owned durable "id" triggers "Invalid resource". Strip it from the
# payload only (the *-desired.json diff keeps it for readability).
$payloadResources = @($desiredSet | ForEach-Object {
    $c = Copy-Json $_
    $c.PSObject.Properties.Remove('id')
    $c
})
$payload = [pscustomobject]@{ '$schema' = $CfgSchema; resources = $payloadResources }
$payload | ConvertTo-Json -Depth 100 | Set-Content -Path $payFile -Encoding UTF8

Write-Host "`nWrote:" -ForegroundColor Cyan
Write-Host "  current : $curFile"
Write-Host "  desired : $desFile"
Write-Host "  payload : $payFile"
Write-Host "`nDiff the first two, e.g.:" -ForegroundColor Yellow
Write-Host "  code --diff `"$curFile`" `"$desFile`"   (or)   git diff --no-index `"$curFile`" `"$desFile`""

if (-not $Submit) {
    Write-Host "`nDry run only - nothing sent to Partner Center. Re-run with -Submit to POST to draft." -ForegroundColor Yellow
    return
}

# --- Submit path: auth + POST + poll ---------------------------------------
$headers = @{ Authorization = "Bearer $(Get-IngestionToken)" }

Write-Host "`nSubmitting configure request..." -ForegroundColor Cyan
$body = $payload | ConvertTo-Json -Depth 100
$job  = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
    -Uri "$GraphBase/configure?`$version=$ConfigureVersion" -Body $body
Write-Host "  jobID: $($job.jobID)  status: $($job.jobStatus)" -ForegroundColor DarkGray

# Poll until terminal
do {
    Start-Sleep -Seconds 3
    $status = Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "$GraphBase/configure/$($job.jobID)/status?`$version=$ConfigureVersion"
    Write-Host "  $($status.jobStatus) / $($status.jobResult)" -ForegroundColor DarkGray
} while ($status.jobStatus -eq 'running' -or $status.jobStatus -eq 'pending')

if ($status.jobResult -eq 'succeeded') {
    Write-Host "`nConfigure succeeded - draft updated. Review in Partner Center, then publish." -ForegroundColor Green
} else {
    Write-Host "`nConfigure did not succeed: $($status.jobResult)" -ForegroundColor Red
    Write-ConfigureErrors $status
}
