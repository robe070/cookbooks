<#
.SYNOPSIS
    Builds corrected virtual-machine-plan-technical-configuration resources for a set
    of draft VM plans, using another plan as the template for VM sizes / ports /
    properties. Dry-run by default: writes current-vs-desired JSON for diffing and
    a ready-to-send configure payload, but does NOT write to Partner Center unless
    you pass -Submit.

.DESCRIPTION
    Purpose-built for the "LANSA Scalable License" WS2025 fix: the four w25* draft
    plans need their technical configuration set to a single x64Gen2 (Trusted Launch)
    SKU, OS = windows/other, with recommended VM sizes / open ports / VM properties
    copied from the w22d-15-0 plan. The VM image is added separately later, so
    vmImageVersions is left empty.

    Because the Product Ingestion API is declarative, submitting the desired tech
    config replaces the plan's existing skus array in place -- for unpublished drafts
    with no image yet this avoids the portal's delete-and-re-add workaround.

    WORKFLOW
      1. Run with no -Submit  -> produces <out>-current.json, <out>-desired.json,
         and <out>-configure-payload.json. Diff the first two.
      2. Happy with the diff  -> re-run with -Submit (+ auth) to POST to configure
         (updates DRAFT only; nothing goes live until you publish in the portal).

.PARAMETER TemplateFile
    Path to the exported resource-tree JSON (from Export-MarketplaceOffer.ps1).

.PARAMETER SourcePlanExternalId
    Plan whose recommendedVmSizes / openPorts / vmProperties are copied. Default w22d-15-0.

.PARAMETER TargetPlanExternalId
    One or more plan externalIds to correct. Default: the four w25* plans.

.PARAMETER OsFamily / .PARAMETER OsType
    operatingSystem values for the targets. Default windows / other (WS2025 isn't listed).

.PARAMETER ImageType
    SKU image type. Default x64Gen2.

.PARAMETER SecurityType
    SKU security type(s). Default 'trusted' (Trusted Launch).

.PARAMETER SkuIdMap
    Optional hashtable overriding the skuId per target externalId. By default skuId
    equals the plan's externalId (e.g. w25d-16-0). Override if your uploaded image
    SKU names differ (especially for the Japanese '...j' plans).

.PARAMETER OutPrefix
    Path prefix for output files. Default .\ws2025-techconfig

.PARAMETER Submit
    Actually POST the configure payload to Partner Center (updates draft). Requires auth.

.PARAMETER TenantId / .PARAMETER ClientId / .PARAMETER ClientSecret
    App-only (client-credentials) auth for -Submit.

.EXAMPLE
    # Dry run: produce diff + payload, write nothing to Partner Center
    .\Update-VmPlanTechConfig.ps1 -TemplateFile .\9c420de5-...-draft.json

.EXAMPLE
    # After reviewing the diff, submit to draft
    .\Update-VmPlanTechConfig.ps1 -TemplateFile .\9c420de5-...-draft.json `
        -Submit -TenantId $t -ClientId $c -ClientSecret $s
#>
[CmdletBinding()]
param(
    [string] $TemplateFile,

    # Diagnostics only: fetch the detailed status (per-resource errors) for a prior
    # configure jobID and exit. Requires auth. Does not build or submit anything.
    [string] $StatusJobId,

    [string] $SourcePlanExternalId = 'w22d-15-0',

    [string[]] $TargetPlanExternalId = @('w25d-16-0', 'w25d-16-0j', 'w25d-15-0', 'w25d-15-0j'),

    [string] $OsFamily = 'windows',
    [string] $OsType   = 'other',

    [string] $ImageType = 'x64Gen2',

    [string[]] $SecurityType = @('trusted'),

    [hashtable] $SkuIdMap = @{},

    # --- Gallery image (required: the configure API rejects a SKU with no active image) ---
    [string] $SubscriptionId  = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3',
    [string] $ResourceGroup   = 'BakingDP',
    [string] $GalleryName     = 'LansaGallery',
    [string] $GalleryTenantId = '17e16064-c148-4c9b-9892-bb00e9589aa5',
    # Image version is derived from the SKU: w<srv>d-<major>-<minor>[j] -> <major>.<minor>.<ImageBuild>
    # e.g. w25d-16-0 -> 16.0.22, w25d-15-1 -> 15.1.22. Override per plan via ImageVersionMap.
    [string] $ImageBuild      = '22',
    [hashtable] $ImageVersionMap = @{},
    # Image definition = <skuId><ImageDefSuffix> unless overridden per-plan in ImageDefMap.
    [string] $ImageDefSuffix  = '-g2',
    [hashtable] $ImageDefMap  = @{},

    [string] $OutPrefix = '.\ws2025-techconfig',

    # Endpoint $version for the configure API. Acts as a MAX schema-version ceiling
    # for parsing the request; must be >= the resource schema versions in the payload.
    # tech-config's current version is 2026-04-01-preview1, so the ceiling must reach it.
    [string] $ConfigureVersion = '2026-04-01-preview1',

    [switch] $Submit,

    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$GraphBase   = 'https://graph.microsoft.com/rp/product-ingestion'
# Use the CURRENT tech-config schema version (from the resources-index). The write
# path only accepts the current version; older read versions (preview5/preview3 that
# resource-tree returns) are rejected as "Invalid resource".
$TechSchema  = 'https://schema.mp.microsoft.com/schema/virtual-machine-plan-technical-configuration/2026-04-01-preview1'
$CfgSchema   = 'https://schema.mp.microsoft.com/schema/configure/2022-03-01-preview2'

function Get-IngestionToken {
    if (-not ($TenantId -and $ClientId -and $ClientSecret)) { throw "Auth requires -TenantId/-ClientId/-ClientSecret." }
    $resp = Invoke-RestMethod -Method Post `
        -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $ClientSecret; scope = 'https://graph.microsoft.com/.default' }
    return $resp.access_token
}

# Print configure errors from a /status response. The real per-resource reasons live
# in errors[].details[] (the top-level message is just "Invalid resource"); the
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

# Map plan externalId -> plan durable id (e.g. plan/<product>/<guid>)
$planByExternalId = @{}
foreach ($r in $resources) {
    if ((Get-ResType $r) -eq 'plan') { $planByExternalId[$r.identity.externalId] = $r.id }
}

# Index tech-config resources by their plan durable id
$techByPlanId = @{}
foreach ($r in $resources) {
    if ((Get-ResType $r) -eq 'virtual-machine-plan-technical-configuration') { $techByPlanId[$r.plan] = $r }
}

# --- Resolve the source template (sizes / ports / properties) --------------
if (-not $planByExternalId.ContainsKey($SourcePlanExternalId)) {
    throw "Source plan '$SourcePlanExternalId' not found in the template."
}
$sourcePlanId = $planByExternalId[$SourcePlanExternalId]
if (-not $techByPlanId.ContainsKey($sourcePlanId)) {
    throw "Source plan '$SourcePlanExternalId' has no technical configuration to copy from."
}
$src = $techByPlanId[$sourcePlanId]
Write-Host "Template: $SourcePlanExternalId" -ForegroundColor Cyan
Write-Host "  recommendedVmSizes: $($src.recommendedVmSizes -join ', ')" -ForegroundColor DarkGray
Write-Host "  openPorts:          $($src.openPorts.label -join ', ')" -ForegroundColor DarkGray

# Deep-clone helper (round-trip through JSON so nested objects detach cleanly)
function Copy-Json($obj) { $obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json }

# --- Build desired tech configs --------------------------------------------
$currentSet = @()
$desiredSet = @()

foreach ($ext in $TargetPlanExternalId) {
    if (-not $planByExternalId.ContainsKey($ext)) { throw "Target plan '$ext' not found in the template." }
    $planId = $planByExternalId[$ext]
    $cur    = if ($techByPlanId.ContainsKey($planId)) { $techByPlanId[$planId] } else { $null }
    # Single-SKU plan: its one SKU must carry the plan id (the API requires at least one
    # skuId == plan id), so NO -g2 suffix here. (The gallery image def is still <planSKU>-g2.)
    $skuId  = if ($SkuIdMap.ContainsKey($ext)) { $SkuIdMap[$ext] } else { $ext }

    # Start from the current resource if present (preserves id/product/plan), else a stub
    $desired = if ($cur) { Copy-Json $cur } else {
        [pscustomobject]@{ '$schema' = $TechSchema; product = $tree.root; plan = $planId }
    }

    # Apply the corrections
    $desired | Add-Member -NotePropertyName '$schema' -NotePropertyValue $TechSchema -Force  # stamp CURRENT write version
    $desired | Add-Member -NotePropertyName operatingSystem `
        -NotePropertyValue ([pscustomobject]@{ family = $OsFamily; type = $OsType }) -Force
    $desired | Add-Member -NotePropertyName recommendedVmSizes -NotePropertyValue (Copy-Json $src.recommendedVmSizes) -Force
    $desired | Add-Member -NotePropertyName openPorts          -NotePropertyValue (Copy-Json $src.openPorts) -Force
    $desired | Add-Member -NotePropertyName vmProperties       -NotePropertyValue (Copy-Json $src.vmProperties) -Force
    $desired | Add-Member -NotePropertyName skus -NotePropertyValue @(
        [pscustomobject]@{ imageType = $ImageType; skuId = $skuId; securityType = $SecurityType }
    ) -Force

    # Gallery image version (sharedImageGallery source). Required - the API rejects a
    # SKU generation with no active image.
    $imageDef = if ($ImageDefMap.ContainsKey($ext)) { $ImageDefMap[$ext] } else { "$ext$ImageDefSuffix" }  # <ext>-g2
    # Derive image version from the plan externalId: w<srv>d-<major>-<minor>[j] -> <major>.<minor>.<build>
    $imgVer = if ($ImageVersionMap.ContainsKey($ext)) { $ImageVersionMap[$ext] }
              elseif ($ext -match '-(\d+)-(\d+)j?$') { "$($Matches[1]).$($Matches[2]).$ImageBuild" }
              else { throw "Cannot derive image version from plan '$ext'; pass -ImageVersionMap @{ '$ext' = '<x.y.z>' }." }
    $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/images/$imageDef/versions/$imgVer"
    $desired | Add-Member -NotePropertyName vmImageVersions -NotePropertyValue @(
        [pscustomobject]@{
            versionNumber  = $imgVer
            vmImages       = @(
                [pscustomobject]@{
                    imageType = $ImageType
                    source    = [pscustomobject]@{
                        sourceType  = 'sharedImageGallery'
                        sharedImage = [pscustomobject]@{ tenantId = $GalleryTenantId; resourceId = $resourceId }
                    }
                }
            )
            lifecycleState = 'generallyAvailable'
        }
    ) -Force

    $currentSet += if ($cur) { $cur } else { [pscustomobject]@{ plan = $planId; note = '(no technical configuration yet)' } }
    $desiredSet += $desired

    Write-Host ("  {0,-12} -> Gen2/{1}, skuId={2}, image={3} v{4}" -f $ext, ($SecurityType -join '+'), $skuId, $imageDef, $imgVer) -ForegroundColor Green
}

# --- Emit dry-run artifacts ------------------------------------------------
$curFile = "$OutPrefix-current.json"
$desFile = "$OutPrefix-desired.json"
$payFile = "$OutPrefix-configure-payload.json"

$currentSet | ConvertTo-Json -Depth 100 | Set-Content -Path $curFile -Encoding UTF8
$desiredSet | ConvertTo-Json -Depth 100 | Set-Content -Path $desFile -Encoding UTF8

# The configure API identifies a plan-scoped resource by its product+plan refs;
# echoing back the server-owned durable "id" triggers "Invalid resource". Strip it
# from the payload only (the *-desired.json diff keeps it for readability).
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
