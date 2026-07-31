<#
.SYNOPSIS
    Clones existing VM plans into NEW plans via the Product Ingestion API, dropping the
    Gen1 image type and keeping only a single Gen2 (Trusted Launch) image at a chosen
    build. Built for the Win2019 case: Marketplace support says you can't remove an image
    type from a live plan (you must deprecate the plan), so instead we create replacement
    Gen2-only plans and deprecate the originals manually.

.DESCRIPTION
    For each source plan it creates a new plan (+ its plan-listing, price-and-availability
    and technical-configuration) with:
      - new plan externalId = <source><NewPlanSuffix>  (e.g. w19d-16-0 -> w19d-16-0-g2)
      - a single x64Gen2 SKU whose skuId = the new plan id (satisfies "one skuId must equal
        the plan id"); Gen1 dropped
      - only the Gen2 image at version x.y.<ImageBuild> (e.g. x.y.23) - other versions dropped
      - listing / pricing / markets / OS / VM sizes / ports copied verbatim from the source

    Schema versions are the CURRENT ones from the resources-index (the export returns stale
    versions the WRITE path rejects). Dry-run by default; -Submit POSTs one configure per new
    plan (draft). Deprecating the OLD plans is done manually in the portal.

.EXAMPLE
    .\New-MarketplaceVmPlan.ps1 -TemplateFile .\product-9c420de5-...-draft.json          # dry run
    .\New-MarketplaceVmPlan.ps1 -TemplateFile .\product-9c420de5-...-draft.json `
        -SourcePlanExternalId w19d-15-0 -Submit -TenantId $t -ClientId $c -ClientSecret $s   # one plan
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TemplateFile,
    [string[]] $SourcePlanExternalId = @('w19d-16-0', 'w19d-16-0j', 'w19d-15-0', 'w19d-15-0j'),
    [string] $NewPlanSuffix = '-g2',
    [string] $NameSuffix = ' (Gen2)',               # appended to plan alias + listing name (must be unique in the offer)
    [int] $StartDisplayRank = 26,                   # ranks assigned 26,27,28,29 by RankOrder position (reorder in the UI later)
    [string] $ImageBuild = '23',                    # keep only the Gen2 x.y.<build> image
    [string[]] $SecurityType = @('trusted'),
    [string] $OutPrefix = '.\new-w19-plans',
    [switch] $Submit,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($SourcePlanExternalId) { $SourcePlanExternalId = $SourcePlanExternalId -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

$GraphBase = 'https://graph.microsoft.com/rp/product-ingestion'
$CfgSchema = 'https://schema.mp.microsoft.com/schema/configure/2022-03-01-preview2'

function Get-IngestionToken {
    if (-not ($TenantId -and $ClientId -and $ClientSecret)) { throw "Auth requires -TenantId/-ClientId/-ClientSecret." }
    (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $ClientSecret; scope = 'https://graph.microsoft.com/.default' }).access_token
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

# --- Load template ---------------------------------------------------------
# Each cloned resource keeps the $schema the EXPORT gave it. Those are the versions the
# API actually serves/accepts (the resources-index also lists newer versions like
# plan/preview4 that the WRITE path rejects with "schema could not be found"). Provided the
# export was taken at a current ceiling (Export-MarketplaceOffer.ps1 defaults to
# 2026-04-01-preview1), tech-config already comes back as the current 2026-04-01-preview1.
$tree = Get-Content -Raw $TemplateFile | ConvertFrom-Json
$prod = $tree.root
$planIdByExt = @{}
foreach ($r in $tree.resources) { if ((Get-ResType $r) -eq 'plan') { $planIdByExt[$r.identity.externalId] = $r.id } }

# Endpoint $version ceiling = highest schema version among the resource types we submit.
$types = @('plan', 'plan-listing', 'price-and-availability-plan', 'virtual-machine-plan-technical-configuration')
$ConfigureVersion = @($tree.resources | Where-Object { (Get-ResType $_) -in $types } |
    ForEach-Object { ($_.'$schema' -split '/')[-1] }) | Sort-Object -Descending | Select-Object -First 1
Write-Host "endpoint `$version = $ConfigureVersion (resource `$schemas kept from the export)`n" -ForegroundColor Cyan

# Canonical order for stable displayRank (position N -> StartDisplayRank + N), so a
# single-plan test and the full run give each plan the same rank.
$RankOrder = @('w19d-16-0', 'w19d-16-0j', 'w19d-15-0', 'w19d-15-0j')

# --- Build a new plan (4 resources) per source -----------------------------
$newPlans = @()
foreach ($src in $SourcePlanExternalId) {
    if (-not $planIdByExt.ContainsKey($src)) { throw "Source plan '$src' not found in template." }
    $srcId   = $planIdByExt[$src]
    $newExt  = "$src$NewPlanSuffix"
    $rn      = ($newExt -replace '[^A-Za-z0-9]', '_')          # in-payload handle for the new plan

    $srcPlan = $tree.resources | Where-Object { (Get-ResType $_) -eq 'plan' -and $_.id -eq $srcId }
    $srcListings = @($tree.resources | Where-Object { (Get-ResType $_) -eq 'plan-listing' -and $_.plan -eq $srcId })
    $srcPap  = $tree.resources | Where-Object { (Get-ResType $_) -eq 'price-and-availability-plan' -and $_.plan -eq $srcId }
    $srcTech = $tree.resources | Where-Object { (Get-ResType $_) -eq 'virtual-machine-plan-technical-configuration' -and $_.plan -eq $srcId }
    if (-not ($srcPlan -and $srcListings -and $srcPap -and $srcTech)) { throw "Source plan '$src' is missing one of its 4 resources." }

    # Pick the Gen2 image at x.y.<ImageBuild>
    $img = $srcTech.vmImageVersions | Where-Object {
        $_.versionNumber -match "\.$ImageBuild$" -and (@($_.vmImages | Where-Object { $_.imageType -eq 'x64Gen2' }).Count -gt 0)
    } | Select-Object -First 1
    if (-not $img) { throw "Source plan '$src' has no Gen2 image at version *.$ImageBuild - cannot clone." }

    # Stable displayRank by position in the canonical order (falls back to source rank).
    $rankIdx = [array]::IndexOf($RankOrder, $src)
    $rank = if ($rankIdx -ge 0) { $StartDisplayRank + $rankIdx } else { $srcPlan.displayRank }

    # plan (keep the source plan's own $schema)
    $np = [pscustomobject]@{
        '$schema'    = $srcPlan.'$schema'
        resourceName = $rn
        identity     = [pscustomobject]@{ externalId = $newExt }
        alias        = "$($srcPlan.alias)$NameSuffix"
        azureRegions = @($srcPlan.azureRegions)   # force array (a 1-element array must not collapse to a string)
        displayRank  = $rank
        product      = $prod
    }

    # plan-listing(s) - one per language; append the name suffix (keep source $schema)
    $newListings = foreach ($l in $srcListings) {
        $nl = Copy-Json $l
        $nl.PSObject.Properties.Remove('id')
        $nl.plan = [pscustomobject]@{ resourceName = $rn }
        $nl.name = "$($l.name)$NameSuffix"
        $nl
    }

    # price-and-availability-plan (keep source $schema)
    $npap = Copy-Json $srcPap
    $npap.PSObject.Properties.Remove('id')
    $npap.plan = [pscustomobject]@{ resourceName = $rn }

    # technical-configuration: Gen2-only SKU + single Gen2 image (keep source $schema)
    $ntech = Copy-Json $srcTech
    $ntech.PSObject.Properties.Remove('id')
    $ntech.plan = [pscustomobject]@{ resourceName = $rn }
    $ntech.skus = @([pscustomobject]@{ imageType = 'x64Gen2'; skuId = $newExt; securityType = $SecurityType })
    $imgClone = Copy-Json $img
    $imgClone.vmImages = @($imgClone.vmImages | Where-Object { $_.imageType -eq 'x64Gen2' })
    $ntech.vmImageVersions = @($imgClone)

    $resources = @($np) + @($newListings) + @($npap, $ntech)
    $newPlans += [pscustomobject]@{ Source = $src; NewExternalId = $newExt; Resources = $resources }

    $imgRef = ($imgClone.vmImages[0].source.sharedImage.resourceId -replace '.*/images/', '')
    Write-Host ("  {0,-12} -> {1,-15} rank={2} image {3}" -f $src, $newExt, $rank, $imgRef) -ForegroundColor Green
    Write-Host ("       name: `"$($np.alias)`"") -ForegroundColor DarkGray
}

# --- Dry-run artefacts -----------------------------------------------------
$payFile = "$OutPrefix-configure-payloads.json"
($newPlans | ForEach-Object { [pscustomobject]@{ '$schema' = $CfgSchema; resources = $_.Resources } }) |
    ConvertTo-Json -Depth 100 | Set-Content -Path $payFile -Encoding UTF8
Write-Host "`nWrote per-plan configure payloads: $payFile" -ForegroundColor Cyan

if (-not $Submit) { Write-Host "`nDry run only - nothing sent. Re-run with -Submit (test one via -SourcePlanExternalId first)." -ForegroundColor Yellow; return }

# --- Submit: one configure per new plan ------------------------------------
$headers = @{ Authorization = "Bearer $(Get-IngestionToken)" }
$fail = 0
foreach ($p in $newPlans) {
    Write-Host "`nCreating $($p.NewExternalId) ..." -ForegroundColor Cyan
    $payload = [pscustomobject]@{ '$schema' = $CfgSchema; resources = $p.Resources }
    $job = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
        -Uri "$GraphBase/configure?`$version=$ConfigureVersion" -Body ($payload | ConvertTo-Json -Depth 100)
    do {
        Start-Sleep -Seconds 3
        $status = Invoke-RestMethod -Method Get -Headers $headers -Uri "$GraphBase/configure/$($job.jobID)/status?`$version=$ConfigureVersion"
    } while ($status.jobStatus -in @('running', 'pending'))
    if ($status.jobResult -eq 'succeeded') {
        Write-Host "  created (job $($job.jobID)) - draft updated." -ForegroundColor Green
    } else {
        Write-Host "  FAILED (job $($job.jobID)): $($status.jobResult)" -ForegroundColor Red
        Write-ConfigureErrors $status
        $fail++
    }
}
if ($fail -gt 0) { throw "$fail plan(s) failed to create." }
Write-Host "`nAll new plans created in draft. Review in Partner Center, deprecate the old w19 plans, then publish." -ForegroundColor Green
