<#
.SYNOPSIS
    Exports an existing Microsoft Marketplace offer (Azure VM) from Partner Center
    as a single resource-tree JSON file, using the Product Ingestion API.

.DESCRIPTION
    This is the READ/EXPORT half of an offer-cloning workflow. It:
      1. Acquires a Microsoft Entra access token (client-credentials flow).
      2. Resolves the offer's durable ID (from its external/offer ID if needed).
      3. GETs the full resource-tree for the offer (product + properties +
         listing + plans + pricing + VM technical config).
      4. Saves the raw JSON to disk and prints a summary of what it contains.

    Nothing is created or modified. Run this first to confirm API access and to
    capture a template you can later scrub + re-POST via `configure` to create a
    new offer.

    Prerequisites (one-time):
      - A Microsoft Entra app associated with your Partner Center account,
        assigned the **Manager** role (Partner Center > Account settings > Users).
      - The app's Tenant ID, Client ID, and a client secret (key).

    Docs: https://learn.microsoft.com/en-us/partner-center/marketplace-offers/product-ingestion-api

.PARAMETER TenantId
    Microsoft Entra tenant (directory) ID associated with the Partner Center account.

.PARAMETER ClientId
    Application (client) ID of the associated Entra app.

.PARAMETER ClientSecret
    Client secret / key for the Entra app. Prefer piping in from a secret store
    (Key Vault, SecretManagement) rather than hard-coding.

.PARAMETER OfferExternalId
    The offer's external ID (the "Offer ID" shown in Partner Center, e.g.
    "contoso-vm-offer"). Provide this OR -ProductDurableId (one is required).

.PARAMETER ProductDurableId
    The system durable ID, e.g. "product/9c420de5-..." (or just the bare GUID —
    it's the GUID in the offer's dashboard URL). Preferred: no lookup needed.
    Provide this OR -OfferExternalId (one is required).

.PARAMETER TargetType
    Which environment's configuration to export: draft (default), preview, or live.

.PARAMETER OutFile
    Path to write the exported JSON. Defaults to .\<externalId>-<targetType>.json

.PARAMETER SchemaVersion
    Resource-tree schema version ($version). Acts as a "max" version; the API
    returns the latest available at or below this for each resource.

.EXAMPLE
    .\Export-MarketplaceOffer.ps1 -TenantId $t -ClientId $c -ClientSecret $s `
        -ProductDurableId "product/9c420de5-61a6-4219-91d7-0ddb78e3c2a1" -TargetType live

.NOTES
    The Product Ingestion API is in preview. Media (VM images/SAS blobs, logos,
    screenshots) and secrets are NOT fully represented in this JSON and won't be
    cloned by re-POSTing alone — they're handled/uploaded separately.
#>
[CmdletBinding()]
param(
    # App-only (client-credentials) auth.
    [string] $TenantId,

    [string] $ClientId,

    [string] $ClientSecret,

    # Supply EITHER -ProductDurableId (preferred; it's the GUID in the offer's
    # dashboard URL) OR -OfferExternalId (the Offer ID). Validated at runtime.
    [string] $OfferExternalId,

    [string] $ProductDurableId,

    [ValidateSet('draft', 'preview', 'live')]
    [string] $TargetType = 'draft',

    [string] $OutFile,

    [string] $SchemaVersion = '2026-04-01-preview1'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$GraphBase = 'https://graph.microsoft.com/rp/product-ingestion'

# --- 1. Acquire access token (app-only client-credentials) -----------------
if (-not ($TenantId -and $ClientId -and $ClientSecret)) {
    throw "Auth requires -TenantId, -ClientId and -ClientSecret."
}
Write-Host "Acquiring Entra access token (client credentials)..." -ForegroundColor Cyan
$tokenResponse = Invoke-RestMethod -Method Post `
    -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{
        grant_type    = 'client_credentials'
        client_id     = $ClientId
        client_secret = $ClientSecret
        scope         = 'https://graph.microsoft.com/.default'
    }
$headers = @{ Authorization = "Bearer $($tokenResponse.access_token)" }

# --- 2. Resolve the product durable ID -------------------------------------
if (-not ($ProductDurableId -or $OfferExternalId)) {
    throw "Provide either -ProductDurableId (e.g. 'product/<guid>' or just '<guid>', the GUID in the offer's dashboard URL) or -OfferExternalId (the Offer ID)."
}

if ($ProductDurableId) {
    # Use the durable ID directly; no lookup needed.
    $resolvedExternalId = ($ProductDurableId -replace '[^a-zA-Z0-9]', '-')
}
else {
    Write-Host "Resolving durable ID for offer '$OfferExternalId'..." -ForegroundColor Cyan
    $productLookup = Invoke-RestMethod -Method Get -Headers $headers `
        -Uri "$GraphBase/product?externalID=$([uri]::EscapeDataString($OfferExternalId))&`$version=2022-07-01"

    $product = $productLookup.value | Select-Object -First 1
    if (-not $product) {
        throw "No product found with external ID '$OfferExternalId'. Check the Offer ID and that the Entra app has the Manager role."
    }
    $ProductDurableId = $product.id            # e.g. "product/12345678-..."
    $resolvedExternalId = $OfferExternalId
    Write-Host "  -> $ProductDurableId (type: $($product.type))" -ForegroundColor DarkGray
}

# Normalise durable ID to the "product/<guid>" form the resource-tree path wants
$productPath = if ($ProductDurableId -like 'product/*') { $ProductDurableId } else { "product/$ProductDurableId" }

# --- 3. GET the full resource-tree -----------------------------------------
Write-Host "Fetching resource-tree ($TargetType)..." -ForegroundColor Cyan
$treeUri = "$GraphBase/resource-tree/$productPath" +
           "?targetType=$TargetType&`$version=$SchemaVersion"

$tree = Invoke-RestMethod -Method Get -Headers $headers -Uri $treeUri

# --- 4. Save + summarise ----------------------------------------------------
if (-not $OutFile) {
    $safeName = ($resolvedExternalId -replace '[^a-zA-Z0-9._-]', '_')
    $OutFile  = Join-Path (Get-Location) "$safeName-$TargetType.json"
}

$tree | ConvertTo-Json -Depth 100 | Set-Content -Path $OutFile -Encoding UTF8
Write-Host "`nSaved offer configuration to: $OutFile" -ForegroundColor Green

# Print a summary of the resources captured (schema type + durable id + alias)
Write-Host "`nResources in this offer:" -ForegroundColor Cyan
$tree.resources | ForEach-Object {
    $type  = ($_.'$schema' -split '/schema/')[-1] -replace '/.*$', ''
    $alias = if ($_.PSObject.Properties.Name -contains 'alias') { $_.alias } else { '' }
    '{0,-22} {1,-55} {2}' -f $type, $_.id, $alias
}

Write-Host "`nDone. Next step (clone): scrub the 'id' durable IDs, change the" -ForegroundColor Yellow
Write-Host "product/plan 'identity.externalID' values, re-wire dependencies via" -ForegroundColor Yellow
Write-Host "'resourceName', then POST to $GraphBase/configure." -ForegroundColor Yellow
