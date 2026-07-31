<#
.SYNOPSIS
    Adds a Gen2 (Trusted Launch) gallery image to existing VM plans WITHOUT removing
    their current Gen1 SKU/images (dual-generation). Preserves each plan's own OS type,
    VM sizes, ports and properties. Dry-run by default; -Submit POSTs to draft.

.DESCRIPTION
    For the 8 published LANSA plans (WS2019/WS2022 x V15/V16 x en/ja) that are currently
    Gen1-only. For each plan it:
      - keeps the existing x64Gen1 SKU and all existing image versions,
      - appends an x64Gen2 SKU (skuId = plan SKU, securityType=['trusted']),
      - appends a Gen2 gallery image version <planSKU>-g2 at the SKU-derived version
        x.y.<ImageBuild> (e.g. w22d-16-0 -> 16.0.22).
    Resource is stamped with the current tech-config schema; server-owned id dropped.

.PARAMETER DropNonGalleryImages
    Drop legacy non-gallery (sasUri) image versions before submitting, keeping only
    sharedImageGallery versions (plus the new Gen2 one). Use if the API rejects expired
    SAS URIs. Off by default (existing versions preserved as-is).

.EXAMPLE
    .\Add-Gen2ImageToPlans.ps1 -TemplateFile .\9c420de5-...-draft.json                 # dry run, all 8
    .\Add-Gen2ImageToPlans.ps1 -TemplateFile .\9c420de5-...-draft.json -TargetPlanExternalId w22d-16-0 -Submit -TenantId $t -ClientId $c -ClientSecret $s
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $TemplateFile,
    [string[]] $TargetPlanExternalId = @(
        'w19d-15-0','w19d-15-0j','w22d-15-0','w22d-15-0j',
        'w19d-16-0','w19d-16-0j','w22d-16-0','w22d-16-0j'
    ),
    [string[]] $SecurityType = @('trusted'),
    # Gallery coordinates (same gallery the existing Gen1 images use)
    [string] $SubscriptionId  = '739c4e86-bd75-4910-8d6e-d7eb23ab94f3',
    [string] $ResourceGroup   = 'BakingDP',
    [string] $GalleryName     = 'LansaGallery',
    [string] $GalleryTenantId = '17e16064-c148-4c9b-9892-bb00e9589aa5',
    [string] $ImageBuild      = '22',
    [string] $ImageDefSuffix  = '-g2',
    [hashtable] $ImageVersionMap = @{},
    [hashtable] $ImageDefMap  = @{},
    [switch] $DropNonGalleryImages,
    [string] $OutPrefix = '.\gen2-dual',
    [string] $ConfigureVersion = '2026-04-01-preview1',
    [switch] $Submit,
    [string] $TenantId,
    [string] $ClientId,
    [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$GraphBase  = 'https://graph.microsoft.com/rp/product-ingestion'
$TechSchema = 'https://schema.mp.microsoft.com/schema/virtual-machine-plan-technical-configuration/2026-04-01-preview1'
$CfgSchema  = 'https://schema.mp.microsoft.com/schema/configure/2022-03-01-preview2'

function Get-IngestionToken {
    if (-not ($TenantId -and $ClientId -and $ClientSecret)) { throw "Auth requires -TenantId/-ClientId/-ClientSecret." }
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
function Test-Gallery($img) { $img.source.sourceType -eq 'sharedImageGallery' }

$tree = Get-Content -Raw $TemplateFile | ConvertFrom-Json
$planIdByExt = @{}; $techByPlanId = @{}
foreach ($r in $tree.resources) {
    switch (Get-ResType $r) {
        'plan' { $planIdByExt[$r.identity.externalId] = $r.id }
        'virtual-machine-plan-technical-configuration' { $techByPlanId[$r.plan] = $r }
    }
}

$currentSet = @(); $desiredSet = @()
foreach ($ext in $TargetPlanExternalId) {
    if (-not $planIdByExt.ContainsKey($ext)) { throw "Target plan '$ext' not found." }
    $planId = $planIdByExt[$ext]
    $cur = $techByPlanId[$planId]
    if (-not $cur) { throw "Plan '$ext' has no existing technical configuration to extend." }

    $desired = Copy-Json $cur
    $desired.'$schema' = $TechSchema              # in-place: keeps $schema in its original position
    $desired.PSObject.Properties.Remove('id')     # server-owned; write identifies by product+plan

    # Gen2 SKU id and gallery image definition share one name: <planSKU>-g2
    # (imageType+skuId must be unique within a plan, so Gen2 cannot reuse the Gen1 skuId).
    $g2Name = if ($ImageDefMap.ContainsKey($ext)) { $ImageDefMap[$ext] } else { "$ext$ImageDefSuffix" }

    # --- SKUs: keep existing, append Gen2 if absent ---
    $skus = @($desired.skus)
    if (-not ($skus | Where-Object { $_.imageType -eq 'x64Gen2' })) {
        $skus += [pscustomobject]@{ imageType = 'x64Gen2'; skuId = $g2Name; securityType = $SecurityType }
    }
    $desired.skus = $skus

    # --- Image versions: optionally drop non-gallery, then append the Gen2 version ---
    $imgVer = if ($ImageVersionMap.ContainsKey($ext)) { $ImageVersionMap[$ext] }
              elseif ($ext -match '-(\d+)-(\d+)j?$') { "$($Matches[1]).$($Matches[2]).$ImageBuild" }
              else { throw "Cannot derive image version from '$ext'; pass -ImageVersionMap." }
    $imageDef = $g2Name
    $resourceId = "/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Compute/galleries/$GalleryName/images/$imageDef/versions/$imgVer"

    $versions = @($desired.vmImageVersions)
    if ($DropNonGalleryImages) {
        $versions = @($versions | Where-Object { @($_.vmImages | Where-Object { Test-Gallery $_ }).Count -eq $_.vmImages.Count })
    }
    if (-not ($versions | Where-Object { $_.versionNumber -eq $imgVer })) {
        $versions += [pscustomobject]@{
            versionNumber  = $imgVer
            vmImages       = @([pscustomobject]@{
                imageType = 'x64Gen2'
                source    = [pscustomobject]@{
                    sourceType  = 'sharedImageGallery'
                    sharedImage = [pscustomobject]@{ tenantId = $GalleryTenantId; resourceId = $resourceId }
                }
            })
            lifecycleState = 'generallyAvailable'
        }
    }
    $desired.vmImageVersions = $versions

    $genList = ($desired.skus.imageType | Sort-Object -Unique) -join '+'
    Write-Host ("  {0,-12} SKUs: {1,-16} + Gen2 image {2} v{3}" -f $ext, $genList, $imageDef, $imgVer) -ForegroundColor Green

    $currentSet += $cur
    $desiredSet += $desired
}

$curFile = "$OutPrefix-current.json"; $desFile = "$OutPrefix-desired.json"; $payFile = "$OutPrefix-configure-payload.json"
$currentSet | ConvertTo-Json -Depth 100 | Set-Content -Path $curFile -Encoding UTF8
$desiredSet | ConvertTo-Json -Depth 100 | Set-Content -Path $desFile -Encoding UTF8
# strip id already done; payload = desired resources
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
