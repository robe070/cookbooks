<#
.SYNOPSIS
    Uploads the LANSA solution-template package .zip files to the "LANSA Scalable Stack
    Windows" Azure Application (Solution template) Marketplace offer and binds each to its
    plan's DRAFT, via the Partner Center submission API. Draft only - no publish/go-live.

.DESCRIPTION
    Azure Application (Solution template) offers are NOT supported by the modern Product
    Ingestion API (graph.microsoft.com/rp/product-ingestion) - a resource-tree GET returns
    "Type AzureApplication is not supported". They are managed instead by the Partner Center
    submission API at https://api.partner.microsoft.com/v1.0/ingestion, using an Entra
    client-credentials token whose *resource* is https://api.partner.microsoft.com (NOT the
    graph audience) and whose app has the Manager role in Partner Center (same app used for
    the VM offer).

    Per plan (variant) the flow is (mirrors Microsoft's own
    microsoft/microsoft-partner-center-github-action):
      1. GET  /products                              -> product by externalIDs[].value == offer
      2. GET  /products/{p}/variants                 -> variant by externalID == plan id
      3. GET  /products/{p}/branches/getByModule(module=Package)
                                                     -> currentDraftInstanceID for the variant
      4. POST /products/{p}/packages                 -> Microsoft-issued write SAS + packageId
      5. PUT  {fileSasUri}                            -> upload the .zip bytes (BlockBlob)
      6. PUT  /products/{p}/packages/{id}            -> State=Uploaded
      7. GET  /products/{p}/packages/{id}            -> poll until state == Processed
      8. GET  /products/{p}/packageConfigurations/getByInstanceID(instanceID={draft})
      9. PUT  /products/{p}/packageconfigurations/{id}  (AzureSolutionTemplatePackageConfiguration)
                                                     -> bind new version + package to the plan

    You do NOT self-host the zip: Microsoft hands you a one-time write SAS (step 4); this is
    the same upload the portal drag-and-drop does under the hood.

    Dry-run by default (resolves + prints what it would upload). -Submit performs the writes.

.EXAMPLE
    # dry run - validates local zips + (if creds given) resolves the offer/plans, no writes
    .\Publish-SolutionTemplateOffer.ps1 -ArtefactsPath '.\Solution Template' -RunName CI-Templates-4786 `
        -ClientId $c -ClientSecret $s

.EXAMPLE
    # real submit to the offer draft
    .\Publish-SolutionTemplateOffer.ps1 -ArtefactsPath '.\Solution Template' -RunName CI-Templates-4786 `
        -ClientId $c -ClientSecret $s -Submit
#>
[CmdletBinding()]
param(
    [string]   $OfferExternalId = 'lansa-scalable-stack-win-2019',
    [Parameter(Mandatory)] [string] $ArtefactsPath,   # the "Solution Template" artefact dir holding the zips
    [string]   $RunName,                              # e.g. "CI-Templates-4786" - trailing digits make the package unique
    [string]   $RunNumber,                            # explicit override (full run number); else parsed from -RunName
    [string]   $LansaVersion = '16-0',                # hard-coded LANSA version embedded in the zip name / offer version
    [string[]] $PlanExternalId,                       # optional filter (default: all 6 plans)
    [switch]   $Submit,
    [string]   $TenantId = '17e16064-c148-4c9b-9892-bb00e9589aa5',
    [Parameter(Mandatory)] [string] $ClientId,
    [Parameter(Mandatory)] [string] $ClientSecret
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ApiHost = 'https://api.partner.microsoft.com'
$ApiBase = "$ApiHost/v1.0/ingestion"

# Plan (variant externalID) -> source zip in the artefact dir. The uploaded file name inserts
# "-<LansaVersion>-<run>" before .zip so every submission's package name is unique (Marketplace
# tracks packages by file name). e.g. SolutionTemplateDev.zip -> SolutionTemplateDev-16-0-4786.zip
$PlanZipMap = [ordered]@{
    'custom'      = 'SolutionTemplate.zip'
    'development' = 'SolutionTemplateDev.zip'
    'large'       = 'SolutionTemplateLarge.zip'
    'medium'      = 'SolutionTemplateMedium.zip'
    'small'       = 'SolutionTemplateSmall.zip'
    'test'        = 'SolutionTemplateTest.zip'
}

# --- Run suffix (unique per pipeline run) ----------------------------------
if (-not $RunNumber) {
    if (-not $RunName) { throw "Provide -RunNumber or -RunName (e.g. 'CI-Templates-4786')." }
    $m = [regex]::Match($RunName, '(\d+)\s*$')
    if (-not $m.Success) { throw "Could not parse a trailing run number from RunName '$RunName'." }
    $RunNumber = $m.Groups[1].Value
}
$RunSuffix = ($RunNumber -replace '\D', '')            # full run number (kept whole, so the offer version stays monotonic)
if (-not $RunSuffix) { throw "RunNumber '$RunNumber' has no digits." }
$VerBase   = $LansaVersion -replace '-', '.'           # 16-0 -> 16.0
$Version   = "$VerBase.$RunSuffix"                     # e.g. 16.0.4786

# --- Which plans -----------------------------------------------------------
$plans = @($PlanZipMap.Keys)
if ($PlanExternalId) { $plans = @($plans | Where-Object { $_ -in $PlanExternalId }) }
if (-not $plans) { throw "No plans selected (filter -PlanExternalId matched nothing)." }

# --- Resolve + validate local zips -----------------------------------------
Write-Host "Offer '$OfferExternalId'  version $Version  (run suffix $RunSuffix)`n" -ForegroundColor Cyan
$work = foreach ($p in $plans) {
    $srcName = $PlanZipMap[$p]
    $srcPath = Join-Path $ArtefactsPath $srcName
    $upName  = ($srcName -replace '\.zip$', "-$LansaVersion-$RunSuffix.zip")
    if (-not (Test-Path -LiteralPath $srcPath)) { throw "Plan '$p': zip not found: $srcPath" }
    Write-Host ("  {0,-12} {1,-28} -> {2}" -f $p, $srcName, $upName) -ForegroundColor Green
    [pscustomobject]@{ Plan = $p; SrcPath = $srcPath; FileName = $upName }
}

# ---------------------------------------------------------------------------
function Get-PcToken {
    (Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/token" `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body @{ grant_type = 'client_credentials'; client_id = $ClientId; client_secret = $ClientSecret
                 resource = 'https://api.partner.microsoft.com' }).access_token
}
function ConvertFrom-Jwt {
    param([string]$Jwt)
    $p = $Jwt.Split('.')[1].Replace('-', '+').Replace('_', '/')
    switch ($p.Length % 4) { 2 { $p += '==' } 3 { $p += '=' } }
    [System.Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p)) | ConvertFrom-Json
}
function Invoke-Pc {
    param([string]$Method, [string]$Path, $Body, [hashtable]$ExtraHeaders)
    $h = @{ Authorization = "Bearer $script:Token"; accept = 'application/json' }
    if ($ExtraHeaders) { $ExtraHeaders.GetEnumerator() | ForEach-Object { $h[$_.Key] = $_.Value } }
    $uri = if ($Path -match '^https?://') { $Path } else { "$ApiBase$Path" }
    $req = @{ Method = $Method; Uri = $uri; Headers = $h }
    if ($PSBoundParameters.ContainsKey('Body') -and $null -ne $Body) {
        $req.ContentType = 'application/json'
        $req.Body = ($Body | ConvertTo-Json -Depth 20)
    }
    Invoke-RestMethod @req
}
function Get-AllPc {
    # follow pagination, returning the concatenated .value collection. The API returns a
    # nextLink that is RELATIVE TO THE HOST (e.g. "v1.0/ingestion/products?$skipToken=..."),
    # so it must be joined to $ApiHost - NOT $ApiBase (which already ends in /v1.0/ingestion).
    param([string]$Path)
    $acc = @(); $next = "$ApiBase$Path"
    while ($next) {
        $r = Invoke-Pc -Method Get -Path $next
        if ($r.PSObject.Properties.Name -contains 'value') { $acc += $r.value } else { $acc += $r }
        $nl = $null
        foreach ($p in 'nextLink', '@nextLink', '@odata.nextLink') {
            if ($r.PSObject.Properties.Name -contains $p -and $r.$p) { $nl = $r.$p; break }
        }
        $next = if ($nl) { if ($nl -match '^https?://') { $nl } else { "$ApiHost/$($nl.TrimStart('/'))" } } else { $null }
    }
    $acc
}

# --- Discovery (read-only) -------------------------------------------------
$script:Token = Get-PcToken
$claims = ConvertFrom-Jwt $script:Token
$rolesTxt = if ($claims.PSObject.Properties.Name -contains 'roles') { $claims.roles -join ',' } else { '(none)' }
Write-Host ("`nToken: aud={0} appid={1} tid={2} roles={3}" -f $claims.aud, $claims.appid, $claims.tid, $rolesTxt) -ForegroundColor DarkGray
if ($claims.aud -notmatch 'api\.partner\.microsoft\.com') {
    Write-Host "  WARNING: token audience is not https://api.partner.microsoft.com - the ingestion API will 404/401." -ForegroundColor Yellow
}
Write-Host "Resolving offer ..." -ForegroundColor Cyan

try {
    $products = @(Get-AllPc -Path '/products')
} catch {
    Write-Host "`nGET /products failed: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails.Message) { Write-Host "  body: $($_.ErrorDetails.Message)" -ForegroundColor DarkYellow }
    throw
}
Write-Host "  retrieved $($products.Count) product(s)" -ForegroundColor DarkGray

function Test-ExternalId($p) {
    ($p.PSObject.Properties.Name -contains 'externalIDs') -and
    (@($p.externalIDs | Where-Object { $_.value -eq $OfferExternalId }).Count -gt 0)
}
$product = $products | Where-Object { Test-ExternalId $_ } | Select-Object -First 1
# fallback: match on alias / name (case-insensitive) in case the external id isn't stored verbatim
if (-not $product) {
    $product = $products | Where-Object {
        foreach ($f in 'alias', 'name') {
            if ($_.PSObject.Properties.Name -contains $f -and "$($_.$f)" -in @($OfferExternalId, 'LANSA Scalable Stack Windows', 'LANSA Scalable Stack')) { return $true }
        }
        $false
    } | Select-Object -First 1
    if ($product) { Write-Host "  (matched by alias/name, not external id)" -ForegroundColor Yellow }
}
if (-not $product) {
    Write-Host "`nOffer '$OfferExternalId' not found. Products the app can see:" -ForegroundColor Red
    $products | Select-Object -First 60 | ForEach-Object {
        $ext = if ($_.PSObject.Properties.Name -contains 'externalIDs') { ($_.externalIDs.value -join ',') } else { '' }
        $al  = if ($_.PSObject.Properties.Name -contains 'alias') { $_.alias } else { '' }
        $rt  = if ($_.PSObject.Properties.Name -contains 'resourceType') { $_.resourceType } else { '' }
        Write-Host ("    [{0,-22}] alias='{1}' ext='{2}'" -f $rt, $al, $ext) -ForegroundColor DarkGray
    }
    throw "Offer '$OfferExternalId' not found - see the list above and set -OfferExternalId to the right external id (or tell me the alias)."
}
$productId = $product.id
Write-Host "  product id: $productId" -ForegroundColor DarkGray

$variants = @(Get-AllPc -Path "/products/$productId/variants")
$branches = @((Invoke-Pc -Method Get -Path "/products/$productId/branches/getByModule(module=Package)").value)

function Test-Prop($o, $name) { $o.PSObject.Properties.Name -contains $name }
foreach ($w in $work) {
    $variant = $variants | Where-Object { (Test-Prop $_ 'externalID') -and $_.externalID -eq $w.Plan } | Select-Object -First 1
    if (-not $variant) { throw "Plan '$($w.Plan)' not found as a variant in the offer." }
    $branch = $branches | Where-Object { (Test-Prop $_ 'variantID') -and $_.variantID -eq $variant.id } | Select-Object -First 1
    if (-not $branch) { throw "Plan '$($w.Plan)': no Package draft branch found." }
    Add-Member -InputObject $w -NotePropertyName VariantId       -NotePropertyValue $variant.id
    Add-Member -InputObject $w -NotePropertyName DraftInstanceId -NotePropertyValue $branch.currentDraftInstanceID
    Write-Host ("  {0,-12} variant {1}  draft {2}" -f $w.Plan, $variant.id, $branch.currentDraftInstanceID) -ForegroundColor DarkGray
}

if (-not $Submit) {
    Write-Host "`nDry run only - resolved offer/plans and validated local zips. Re-run with -Submit to upload." -ForegroundColor Yellow
    return
}

# --- Submit: upload + bind per plan ----------------------------------------
$fail = 0
foreach ($w in $work) {
    Write-Host "`n$($w.Plan): uploading $($w.FileName) ..." -ForegroundColor Cyan
    try {
        # 1. create package -> write SAS
        $pkg = Invoke-Pc -Method Post -Path "/products/$productId/packages" `
            -Body @{ resourceType = 'AzureApplicationPackage'; fileName = $w.FileName }
        $packageId = $pkg.id
        $etag      = $pkg.'@odata.etag'

        # 2. upload the zip bytes into the SAS blob
        Invoke-RestMethod -Method Put -Uri $pkg.fileSasUri -InFile $w.SrcPath `
            -ContentType 'application/octet-stream' `
            -Headers @{ 'x-ms-blob-type' = 'BlockBlob'; 'x-ms-version' = '2018-03-28'
                        'x-ms-date' = (Get-Date).ToUniversalTime().ToString('R') } | Out-Null

        # 3. mark Uploaded
        Invoke-Pc -Method Put -Path "/products/$productId/packages/$packageId" -Body @{
            resourceType   = 'AzureApplicationPackage'
            fileName       = $w.FileName
            fileSasUri     = $pkg.fileSasUri
            State          = 'Uploaded'
            '@odata.etag'  = $etag
            id             = $packageId
        } | Out-Null

        # 4. poll until Processed
        $state = 'InProcessing'
        for ($i = 0; $i -lt 30 -and $state -notin @('Processed', 'ProcessFailed'); $i++) {
            Start-Sleep -Seconds 10
            $state = (Invoke-Pc -Method Get -Path "/products/$productId/packages/$packageId").state
            Write-Host "    state: $state" -ForegroundColor DarkGray
        }
        if ($state -ne 'Processed') { throw "package did not reach 'Processed' (last: $state)." }

        # 5. bind the new version + package to the plan's draft config
        $cfg = (Invoke-Pc -Method Get -Path "/products/$productId/packageConfigurations/getByInstanceID(instanceID=$($w.DraftInstanceId))").value | Select-Object -First 1
        if (-not $cfg) { throw "no package configuration for draft $($w.DraftInstanceId)." }
        Invoke-Pc -Method Put -Path "/products/$productId/packageconfigurations/$($cfg.id)" `
            -ExtraHeaders @{ 'If-Match' = $cfg.'@odata.etag' } -Body @{
                resourceType      = 'AzureSolutionTemplatePackageConfiguration'
                version           = $Version
                packageReferences = @(@{ type = 'AzureApplicationPackage'; value = $packageId })
                id                = $cfg.id
            } | Out-Null

        Write-Host "  bound version $Version to plan '$($w.Plan)' (draft)." -ForegroundColor Green
    } catch {
        Write-Host "  FAILED: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) { Write-Host "    $($_.ErrorDetails.Message)" -ForegroundColor DarkYellow }
        $fail++
    }
}
if ($fail -gt 0) { throw "$fail plan(s) failed to update." }
Write-Host "`nAll $($work.Count) plan(s) updated in the offer DRAFT (version $Version). Review + publish in Partner Center." -ForegroundColor Green
