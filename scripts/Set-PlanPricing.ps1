<#
.SYNOPSIS
    Copies one reference plan's price-and-availability configuration (pricing +
    markets + visibility + everything in its price-and-availability-plan resource)
    onto other plans in the same offer, so they all share identical pricing.
    Dry-run by default; writes current/desired/payload JSON for diffing, and only
    POSTs to Partner Center with -Submit.

.DESCRIPTION
    For the "LANSA Scalable License" offer: reference w22d-15-0 (signature 6BA4F5F2500D)
    is the current correct pricing. This clones its price-and-availability-plan onto the
    9 plans that differ, which also normalises w25d-16-0's 141 markets back to the
    standard 62 (the reference set). Each target keeps its own product/plan identity;
    the server-owned "id" is dropped (identified by product+plan).

.PARAMETER TemplateFile          Exported resource-tree JSON.
.PARAMETER ReferencePlanExternalId  Plan whose pricing is the source of truth (default w22d-15-0).
.PARAMETER TargetPlanExternalId  Plans to overwrite. Default = the 9 that differ from the reference.
.PARAMETER OutPrefix             Output file prefix (default .\plan-pricing).
.PARAMETER Submit                POST to configure (updates draft). Requires auth.
.PARAMETER ConfigureVersion      Endpoint $version ceiling (default 2026-04-01-preview1).

.EXAMPLE
    .\Set-PlanPricing.ps1 -TemplateFile .\9c420de5-...-draft.json           # dry run
    .\Set-PlanPricing.ps1 -TemplateFile .\9c420de5-...-draft.json -Submit -TenantId $t -ClientId $c -ClientSecret $s
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TemplateFile,
    [string]   $ReferencePlanExternalId = 'w22d-15-0',
    [string[]] $TargetPlanExternalId = @(
        'w19d-15-0','w19d-15-0j','w22d-15-0j','w25d-15-0j',
        'w19d-16-0','w19d-16-0j','w22d-16-0j','w25d-16-0','w25d-16-0j'
    ),
    [string] $OutPrefix = '.\plan-pricing',
    [string] $ConfigureVersion = '2026-04-01-preview1',
    [switch] $Submit,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret,
    [switch] $UseCurrentAzLogin
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$GraphBase = 'https://graph.microsoft.com/rp/product-ingestion'
$CfgSchema = 'https://schema.mp.microsoft.com/schema/configure/2022-03-01-preview2'

function Get-IngestionToken {
    if ($UseCurrentAzLogin) {
        if (-not (Get-Command Get-AzAccessToken -ErrorAction SilentlyContinue)) { throw "Az.Accounts not available; use -TenantId/-ClientId/-ClientSecret." }
        if (-not (Get-AzContext -ErrorAction SilentlyContinue)) { throw "No active Azure session. Run Connect-AzAccount." }
        $t = Get-AzAccessToken -ResourceUrl 'https://graph.microsoft.com'
        return $(if ($t.Token -is [securestring]) { [System.Net.NetworkCredential]::new('', $t.Token).Password } else { $t.Token })
    }
    if (-not ($TenantId -and $ClientId -and $ClientSecret)) { throw "Auth requires -TenantId/-ClientId/-ClientSecret (or -UseCurrentAzLogin)." }
    (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type='client_credentials'; client_id=$ClientId; client_secret=$ClientSecret; scope='https://graph.microsoft.com/.default' }).access_token
}
function Write-ConfigureErrors($status) {
    foreach ($e in $status.errors) {
        $rid = if ($e.PSObject.Properties.Name -contains 'resourceId') { "  [$($e.resourceId)]" } else { '' }
        Write-Host "  - $($e.message)$rid" -ForegroundColor Red
        if ($e.PSObject.Properties.Name -contains 'details' -and $e.details) {
            foreach ($d in $e.details) { Write-Host "      * $($d.message)" -ForegroundColor DarkYellow }
        }
    }
}
function Copy-Json($o) { $o | ConvertTo-Json -Depth 100 | ConvertFrom-Json }
function Get-ResType($r) { ($r.'$schema' -split '/schema/')[-1] -replace '/.*$', '' }

$tree = Get-Content -Raw $TemplateFile | ConvertFrom-Json
$planIdByExt = @{}; $papByPlanId = @{}
foreach ($r in $tree.resources) {
    switch (Get-ResType $r) {
        'plan'                        { $planIdByExt[$r.identity.externalId] = $r.id }
        'price-and-availability-plan' { $papByPlanId[$r.plan] = $r }
    }
}

if (-not $planIdByExt.ContainsKey($ReferencePlanExternalId)) { throw "Reference plan '$ReferencePlanExternalId' not found." }
$refPap = $papByPlanId[$planIdByExt[$ReferencePlanExternalId]]
if (-not $refPap) { throw "Reference plan '$ReferencePlanExternalId' has no price-and-availability-plan." }
$refMarkets = if ($refPap.PSObject.Properties.Name -contains 'markets') { $refPap.markets.Count } else { 0 }
Write-Host "Reference: $ReferencePlanExternalId ($($refPap.'$schema' -replace '.*/schema/','')) - $refMarkets markets`n" -ForegroundColor Cyan

$currentSet = @(); $desiredSet = @()
foreach ($ext in $TargetPlanExternalId) {
    if (-not $planIdByExt.ContainsKey($ext)) { throw "Target plan '$ext' not found." }
    $planId = $planIdByExt[$ext]
    $cur    = $papByPlanId[$planId]

    $desired = Copy-Json $refPap                 # full clone of reference availability config
    $desired.plan = $planId                       # retarget to this plan (product is the same offer)
    $desired.PSObject.Properties.Remove('id')     # server-owned; identify by product+plan

    $curMk = if ($cur -and $cur.PSObject.Properties.Name -contains 'markets') { $cur.markets.Count } else { 0 }
    Write-Host ("  {0,-12} markets {1,3} -> {2,3}" -f $ext, $curMk, $refMarkets) -ForegroundColor Green

    $currentSet += if ($cur) { $cur } else { [pscustomobject]@{ plan = $planId; note = '(no pricing yet)' } }
    $desiredSet += $desired
}

$curFile = "$OutPrefix-current.json"; $desFile = "$OutPrefix-desired.json"; $payFile = "$OutPrefix-configure-payload.json"
$currentSet | ConvertTo-Json -Depth 100 | Set-Content -Path $curFile -Encoding UTF8
$desiredSet | ConvertTo-Json -Depth 100 | Set-Content -Path $desFile -Encoding UTF8
$payload = [pscustomobject]@{ '$schema' = $CfgSchema; resources = $desiredSet }
$payload | ConvertTo-Json -Depth 100 | Set-Content -Path $payFile -Encoding UTF8

Write-Host "`nWrote:`n  current : $curFile`n  desired : $desFile`n  payload : $payFile" -ForegroundColor Cyan
Write-Host "Diff:  code --diff `"$curFile`" `"$desFile`"" -ForegroundColor Yellow

if (-not $Submit) { Write-Host "`nDry run only - nothing sent. Re-run with -Submit to POST to draft." -ForegroundColor Yellow; return }

$headers = @{ Authorization = "Bearer $(Get-IngestionToken)" }
Write-Host "`nSubmitting configure request..." -ForegroundColor Cyan
$job = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
    -Uri "$GraphBase/configure?`$version=$ConfigureVersion" -Body ($payload | ConvertTo-Json -Depth 100)
Write-Host "  jobID: $($job.jobID)" -ForegroundColor DarkGray
do {
    Start-Sleep -Seconds 3
    $status = Invoke-RestMethod -Method Get -Headers $headers -Uri "$GraphBase/configure/$($job.jobID)/status?`$version=$ConfigureVersion"
    Write-Host "  $($status.jobStatus) / $($status.jobResult)" -ForegroundColor DarkGray
} while ($status.jobStatus -in @('running','pending'))
if ($status.jobResult -eq 'succeeded') {
    Write-Host "`nConfigure succeeded - draft updated. Review in Partner Center, then publish." -ForegroundColor Green
} else {
    Write-Host "`nConfigure did not succeed: $($status.jobResult)" -ForegroundColor Red
    Write-ConfigureErrors $status
}
