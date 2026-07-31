<#
.SYNOPSIS
    Adds a newly-built gallery image version to a Microsoft Marketplace VM plan's
    technical configuration via the Product Ingestion API. Designed to run in the
    "Publish Preview Images" stage: it takes the gallery image URL (as produced by
    the build pipeline) and APPENDS it to the plan's existing tech config.

.DESCRIPTION
    Everything the API needs is derived from the gallery image-version resource id
    (the "ImageUrl"):
      .../galleries/<gallery>/images/<imageDef>/versions/<x.y.z>
        - resourceId  = the whole URL (used verbatim in sharedImage.resourceId)
        - versionNumber = the segment after /versions/
        - imageDef      = the segment after /images/ ; a "-g2" suffix => x64Gen2 and
                          the plan externalId is imageDef minus "-g2"
    Items NOT in the URL: the gallery tenantId and the offer/product durable id are
    hard-coded for the LANSA Scalable License offer; only Partner Center auth is passed in.

    The API is declarative and images are immutable once published, so this GETs the
    plan's current tech config and APPENDS the new version (idempotent - skips if the
    version already exists). It also ensures a Gen2 SKU exists (adds one if missing,
    using the naming rule: the plan-id SKU is <planSKU>; an additional Gen2 SKU is
    <planSKU>-g2). Nothing existing is modified.

    Plan resolution: a plan that was replaced by a Gen2-only clone is named <base>-g2
    (e.g. the w19 plans - the original <base> is deprecated). So the derived/artefact plan
    name is looked up as <base>-g2 first and, if that plan exists, used as the target;
    otherwise the base name is used (w25/w22 plans keep their original ids).

    Two ways to supply images:
      -ImageUrl  <url>       single image (e.g. from $(Gate.ImageUrl))
      -ArtefactsPath <dir>   batch: the built plans are DERIVED from the artefacts - each has a
                             <dir>/<plan>/<plan>.txt with its ImageUrl. -PlanExternalId optionally
                             filters; any plan without an artefact folder is skipped, not an error.

.PARAMETER WhatIf
    Dry run: authenticates and GETs current config, prints the resource that WOULD be
    submitted, but does not POST.

.EXAMPLE
    # Single image (pipeline gate variable):
    .\Add-MarketplaceGen2Image.ps1 -ImageUrl "$(Gate.ImageUrl)" `
        -ClientId $(PCClientId) -ClientSecret $(PCClientSecret)

.EXAMPLE
    # Batch: plans are DERIVED from the downloaded artefacts (one <plan>/<plan>.txt per
    # built plan); no plan list needed. -PlanExternalId can be given to filter.
    .\Add-MarketplaceGen2Image.ps1 `
        -ArtefactsPath "$(Pipeline.Workspace)/_BuildImageReleaseArtefacts" `
        -ClientId $(PCClientId) -ClientSecret $(PCClientSecret)
#>
[CmdletBinding()]
param(
    [string] $ArtefactsPath,
    [string] $ImageUrl,

    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [string] $ClientSecret,

    [string[]] $PlanExternalId,

    [ValidateSet('x64Gen1', 'x64Gen2', 'arm64Gen2')]
    [string] $ImageType,                          # else inferred from the -g2 suffix
    [string[]] $SecurityType = @('trusted'),      # used only when a Gen2 SKU must be added
    [string] $ImageDefSuffix = '-g2',

    [switch] $WhatIf
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Accept a comma-separated string (how Azure Pipelines / -File pass array args) as well as a real array.
if ($PlanExternalId) { $PlanExternalId = $PlanExternalId -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } }

$GraphBase  = 'https://graph.microsoft.com/rp/product-ingestion'
$SchemaBase = 'https://schema.mp.microsoft.com/schema'
$CfgSchema  = "$SchemaBase/configure/2022-03-01-preview2"   # 'configure' isn't in the resources-index; pinned
$LookupVer  = '2022-07-01'                                  # also the resources-index version

# Current virtual-machine-plan-technical-configuration schema: INFERRED from the public
# resources-index so we auto-track Microsoft's version bumps (a stale version is rejected as
# "Invalid resource"). Falls back to the last-known-good version if the index is unreachable.
$TechSchema       = "$SchemaBase/virtual-machine-plan-technical-configuration/2026-04-01-preview1"  # fallback
$ConfigureVersion = '2026-04-01-preview1'                                                           # fallback
try {
    $ref = (Invoke-RestMethod -Method Get -Uri "$SchemaBase/resources-index/$LookupVer").anyOf.'$ref' |
        Where-Object { $_ -match '/virtual-machine-plan-technical-configuration/[^/]+$' } |
        Sort-Object -Descending | Select-Object -First 1
    if ($ref) { $TechSchema = $ref; $ConfigureVersion = ($ref -split '/')[-1]
        Write-Host "tech-config schema (from resources-index): $ConfigureVersion" -ForegroundColor DarkGray }
} catch {
    Write-Host "resources-index unreachable; using pinned tech-config schema $ConfigureVersion" -ForegroundColor DarkYellow
}

# Fixed for the LANSA Scalable License offer and its gallery (do not vary).
$ProductDurableId = 'product/9c420de5-61a6-4219-91d7-0ddb78e3c2a1'
$TenantId  = '17e16064-c148-4c9b-9892-bb00e9589aa5'

function Get-IngestionToken {
    (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $ClientSecret; scope = 'https://graph.microsoft.com/.default' }).access_token
}
function Get-PlanByExternalId($ext) {
    (Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "$GraphBase/plan?product=$([uri]::EscapeDataString($ProductDurableId))&externalID=$([uri]::EscapeDataString($ext))&`$version=$LookupVer").value | Select-Object -First 1
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

# Parse a gallery image-version resourceId into its parts.
function Get-ImageParts([string] $url) {
    if ($url -notmatch '/images/([^/]+)/versions/([^/?]+)') {
        throw "ImageUrl is not a gallery image-version resource id (…/images/<def>/versions/<x.y.z>): $url"
    }
    $def = $Matches[1]; $ver = $Matches[2]
    if ($ImageType) { $type = $ImageType }
    elseif ($def.EndsWith($ImageDefSuffix)) { $type = 'x64Gen2' } else { $type = 'x64Gen1' }
    $plan = if ($def.EndsWith($ImageDefSuffix)) { $def.Substring(0, $def.Length - $ImageDefSuffix.Length) } else { $def }
    [pscustomobject]@{ ResourceId = $url.Trim(); ImageDef = $def; Version = $ver; ImageType = $type; PlanExternalId = $plan }
}

# --- Build the work list ---------------------------------------------------
$work = @()
if ($ImageUrl) {
    $p = Get-ImageParts $ImageUrl
    if ($PlanExternalId -and $PlanExternalId.Count -eq 1) { $p.PlanExternalId = $PlanExternalId[0] }
    $work += $p
}
elseif ($ArtefactsPath) {
    # Derive the plan list from the downloaded artefacts. Each built plan drops a
    # <plan>/<plan>.txt containing its gallery ImageUrl (same layout azure_set_gate_variable.ps1
    # reads). Only built plans have a folder, so the artefacts ARE the SKU list.
    # -PlanExternalId is an optional filter; a plan not present in the artefacts is skipped.
    $plans = if ($PlanExternalId) { $PlanExternalId }
             else { Get-ChildItem -Path $ArtefactsPath -Directory -ErrorAction Stop | Select-Object -ExpandProperty Name }
    foreach ($plan in $plans) {
        $file = Join-Path $ArtefactsPath (Join-Path $plan "$plan.txt")
        if (-not (Test-Path $file)) { Write-Host "skip $plan (no artefact $file - not built this run)" -ForegroundColor DarkGray; continue }
        $url = (Get-Content -Raw $file).Trim()
        $p = Get-ImageParts $url
        $p.PlanExternalId = $plan          # trust the artefact folder name for the plan
        $work += $p
    }
}
else { throw "Provide -ImageUrl (single) or -ArtefactsPath (batch; plans are derived from the artefacts)." }
if (-not $work) { throw "No built-plan artefacts found under $ArtefactsPath - there must be at least one image to publish." }
Write-Host ("Plans to process ({0}): {1}`n" -f $work.Count, (($work.PlanExternalId | Sort-Object) -join ', ')) -ForegroundColor Cyan

# --- Auth -------------------------------------------------------------------
$headers = @{ Authorization = "Bearer $(Get-IngestionToken)" }
Write-Host "Offer: $ProductDurableId`n" -ForegroundColor Cyan

$fail = 0
foreach ($w in $work) {
    Write-Host "=== $($w.PlanExternalId)  ($($w.ImageType) v$($w.Version), def $($w.ImageDef)) ===" -ForegroundColor Cyan

    # Resolve the plan. A plan that was replaced by a Gen2-only clone is named <base>-g2
    # (e.g. w19 plans; the original <base> is being deprecated). Prefer the -g2 plan when it
    # exists, otherwise use the base name (w25/w22 plans keep their original id). This also
    # corrects the -ImageUrl derivation, which strips -g2 to get <base>.
    $candidates = @()
    if (-not $w.PlanExternalId.EndsWith($ImageDefSuffix)) { $candidates += "$($w.PlanExternalId)$ImageDefSuffix" }
    $candidates += $w.PlanExternalId
    $plan = $null; $targetExt = $null
    foreach ($cand in $candidates) {
        $found = Get-PlanByExternalId $cand
        if ($found) { $plan = $found; $targetExt = $cand; break }
    }
    if (-not $plan) { Write-Host "  plan not found (tried: $($candidates -join ', ')) - skipping" -ForegroundColor Red; $fail++; continue }
    if ($targetExt -ne $w.PlanExternalId) { Write-Host "  -> resolved to $targetExt (Gen2 replacement plan)" -ForegroundColor DarkGray }
    $w.PlanExternalId = $targetExt     # use the resolved plan id for the rest of the loop (skuId etc.)
    $planId = $plan.id

    # GET current tech config. A durable-id GET returns the DRAFT; if there's no draft
    # (e.g. the plan is live with no pending edits) that 404s, so fall back to the LIVE
    # config via resource-tree - submitting our change then seeds a fresh draft from it.
    $techId = $planId -replace '^plan/', 'virtual-machine-plan-technical-configuration/'
    $cur = $null; $src = 'draft'
    try {
        $cur = Invoke-RestMethod -Method Get -Headers $headers -Uri "$GraphBase/$techId`?`$version=$ConfigureVersion"
    } catch {
        try {
            $tree = Invoke-RestMethod -Method Get -Headers $headers `
                -Uri "$GraphBase/resource-tree/$ProductDurableId`?targetType=live&`$version=$ConfigureVersion"
            $cur = $tree.resources | Where-Object { $_.'$schema' -match '/virtual-machine-plan-technical-configuration/' -and $_.plan -eq $planId } | Select-Object -First 1
            if ($cur) { $src = 'live' }
        } catch { }
    }
    if (-not $cur) {
        Write-Host "  no technical configuration found (draft or live) - set up its SKUs first. Skipping." -ForegroundColor Red; $fail++; continue
    }
    Write-Host "  base config from: $src" -ForegroundColor DarkGray

    $desired = Copy-Json $cur
    $desired.'$schema' = $TechSchema
    if ($desired.PSObject.Properties.Name -contains 'id') { $desired.PSObject.Properties.Remove('id') }

    # Ensure a SKU exists for this imageType (add if missing).
    $skus = @($desired.skus)
    if (-not ($skus | Where-Object { $_.imageType -eq $w.ImageType })) {
        # skuId rule: if a SKU already carries the plan id, the new one is <plan>-g2; else it takes the plan id.
        $skuId = if ($skus | Where-Object { $_.skuId -eq $w.PlanExternalId }) { "$($w.PlanExternalId)$ImageDefSuffix" } else { $w.PlanExternalId }
        $newSku = [pscustomobject]@{ imageType = $w.ImageType; skuId = $skuId }
        if ($w.ImageType -ne 'x64Gen1' -and $SecurityType) { $newSku | Add-Member securityType $SecurityType }
        $skus += $newSku
        $desired.skus = $skus
        Write-Host "  + added $($w.ImageType) SKU skuId=$skuId" -ForegroundColor Green
    }

    # Append the image version (idempotent).
    $versions = @($desired.vmImageVersions)
    if ($versions | Where-Object { $_.versionNumber -eq $w.Version }) {
        Write-Host "  version $($w.Version) already present - nothing to do." -ForegroundColor Yellow
        continue
    }
    $versions += [pscustomobject]@{
        versionNumber  = $w.Version
        vmImages       = @([pscustomobject]@{
            imageType = $w.ImageType
            source    = [pscustomobject]@{
                sourceType  = 'sharedImageGallery'
                sharedImage = [pscustomobject]@{ tenantId = $TenantId; resourceId = $w.ResourceId }
            }
        })
        lifecycleState = 'generallyAvailable'
    }
    $desired.vmImageVersions = $versions
    Write-Host "  + appended $($w.ImageType) image v$($w.Version)" -ForegroundColor Green

    $payload = [pscustomobject]@{ '$schema' = $CfgSchema; resources = @($desired) }
    if ($WhatIf) {
        Write-Host "  [WhatIf] would POST:" -ForegroundColor Yellow
        $payload | ConvertTo-Json -Depth 100 | Write-Host
        continue
    }

    $job = Invoke-RestMethod -Method Post -Headers $headers -ContentType 'application/json' `
        -Uri "$GraphBase/configure?`$version=$ConfigureVersion" -Body ($payload | ConvertTo-Json -Depth 100)
    do {
        Start-Sleep -Seconds 3
        $status = Invoke-RestMethod -Method Get -Headers $headers -Uri "$GraphBase/configure/$($job.jobID)/status?`$version=$ConfigureVersion"
    } while ($status.jobStatus -in @('running', 'pending'))
    if ($status.jobResult -eq 'succeeded') {
        Write-Host "  submitted OK (job $($job.jobID)) - draft updated." -ForegroundColor Green
    } else {
        Write-Host "  FAILED (job $($job.jobID)): $($status.jobResult)" -ForegroundColor Red
        Write-ConfigureErrors $status
        $fail++
    }
}

if ($fail -gt 0) { Write-Host "`n$fail image(s) failed." -ForegroundColor Red; exit 1 }
Write-Host "`nAll images processed. Review the draft in Partner Center, then publish to preview." -ForegroundColor Green
