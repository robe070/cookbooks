# Marketplace VM offer plans via the Product Ingestion API

The LANSA **Azure VM** Marketplace offer plans are managed via the **Product Ingestion API**
(MS Graph, `https://graph.microsoft.com/rp/product-ingestion`, declarative *configure* model),
because the Partner Center UI has no "copy plan/offer" feature. The scripts live in `scripts/`
(currently on branch `debug/paas`, uncommitted, mostly dry-run by default with an explicit
`-Submit`).

## Offer & plan model

- **Offer:** "LANSA Scalable License", product durable id
  `product/9c420de5-61a6-4219-91d7-0ddb78e3c2a1` (the GUID in the offer dashboard URL *is* the
  durable id). ~26 plans in a {LANSA version} × {Windows Server version} × {en/ja} matrix.
- **Plan externalId convention:** `w<server>d-<lansaver>-<sp>` — e.g. `w25d-16-0` = WS2025
  Datacenter, LANSA 16; suffix `j` = Japanese. `skuId` mirrors the plan externalId.
- Each plan is 4 resources: `plan`, `plan-listing`, `price-and-availability-plan`,
  `virtual-machine-plan-technical-configuration`.

## Auth

Requires an **Entra app associated in Partner Center** → Account settings → User management →
Microsoft Entra applications, assigned the **Manager** role (this is *not* Azure RBAC — it is
separate from `Connect-AzAccount`). App-only client-credentials only, scope
`https://graph.microsoft.com/.default`. Delegated/interactive tokens are **not** accepted by this
API, so the scripts are app-only (the earlier `-UseCurrentAzLogin` option was removed).

## Scripts

- **`Export-MarketplaceOffer.ps1`** — GET `resource-tree/product/<durableid>` → saves the full offer
  JSON. `vmImageVersions` comes back **empty** for modern draft plans (the VHD image does not
  round-trip; it's added separately). Export with `-SchemaVersion 2026-04-01-preview1` to get the
  current shape (incl. gallery images) — see rule 1 below.
- **`Update-VmPlanTechConfig.ps1`** — dry-run by default: builds a corrected tech-config
  `-desired.json` + `-configure-payload.json` for diffing; `-Submit` POSTs to `configure` (draft
  only). Copies recommendedVmSizes/openPorts/vmProperties from a source plan.
- **`Add-Gen2ImageToPlans.ps1`** — preserves a plan's existing tech config and *appends* a Gen2
  SKU + gallery image (dry-run default, `-Submit`, `-DropNonGalleryImages` fallback).
- **`Compare-PlanPricing.ps1` / `Set-PlanPricing.ps1`** — group plans by pricing signature; clone a
  reference plan's whole `price-and-availability-plan` onto targets (dry-run default, `-Submit`).
- **`Add-MarketplaceGen2Image.ps1`** — the pipeline entry point (not dry-run-first): adds a
  newly-built gallery image to each built plan's tech config, driven by the build artefacts. See
  [Pipeline automation](#pipeline-automation-publish-preview-images) below.

## Hard-won configure/WRITE rules (virtual-machine-plan-technical-configuration)

Each of these produced a bare "Invalid resource" until fixed:

1. Resource `$schema` **and** endpoint `?$version` must be the **current** version
   (`2026-04-01-preview1` at time of writing). A resource-tree GET returns stale preview5/preview3 (a
   max-version ceiling) which the WRITE path rejects. Don't hard-code it blindly: the current version
   is published in the resources-index at `schema.mp.microsoft.com/schema/resources-index/2022-07-01`
   (an `anyOf[].$ref` list). `Add-MarketplaceGen2Image.ps1` **infers** it from there at runtime, with
   the last-known-good version pinned as a fallback if the index is unreachable. (`configure` and the
   lookup version aren't in the index, so those stay pinned.)
2. product/plan are referenced as durable-id **strings** (`product/<g>`, `plan/<g>/<g>`); object
   form must be `{externalId}` or `{resourceName}` (note the casing — **not** `{externalID}`).
3. Do **not** echo the resource's own durable `id` in the payload.
4. Business validation requires: `operatingSystem` present (`other` is accepted for WS2025), ≥1 SKU,
   and **≥1 active image per SKU generation** — "add image later" is impossible via API (the portal
   allows it, the API does not). `skuId` must be **unique** across the offer.
5. Real per-resource errors appear only in the status **summary** `errors[].details`; the
   `configure/<job>` detail endpoint 404s for failed jobs — read `errors[].details[]` from
   `configure/<job>/status`.

## Gallery image coordinates (Azure Compute Gallery)

tenantId `17e16064-c148-4c9b-9892-bb00e9589aa5`, subscription
`739c4e86-bd75-4910-8d6e-d7eb23ab94f3`, RG `BakingDP`, gallery `LansaGallery`. Source shape:
`vmImageVersions[].vmImages[].source = {sourceType:'sharedImageGallery', sharedImage:{tenantId,
resourceId}}` where `resourceId` is the full image **version** ARM id
`.../galleries/LansaGallery/images/<imageDef>/versions/<ver>`.

- Gen2 image defs = `<planSKU>-g2` (e.g. `w25d-15-0j-g2`); legacy Gen1 defs = `<planSKU>` (no suffix).
- Image **version is derived from the SKU**: `w<srv>d-<major>-<minor>[j]` → `<major>.<minor>.<build>`
  (e.g. `w25d-16-0` → 16.0.22). `Update-VmPlanTechConfig.ps1` encodes this via `-ImageBuild`,
  `-ImageVersionMap`, `-ImageDefMap`.

## SKU / Gen2 rules

Two constraints, both enforced by the API:
1. `imageType`+`skuId` must be **unique within a plan** (Gen1 and Gen2 can't share a skuId).
2. At least **one** SKU's `skuId` must **equal the plan id** `<planSKU>` (else: "One of the SkuIds
   should match plan Id …"). An existing SKU can only be modified if it has not yet been published.

Resulting convention: the plan-id-matching SKU uses `<planSKU>`; any **additional** Gen2 SKU uses
`<planSKU>-g2`. The gallery image def is **always** `<planSKU>-g2` for Gen2 regardless of skuId
(images link by `imageType`, not skuId), and the version is always derived from the plan externalId
(not the `-g2` name, which wouldn't match the `-N-N` regex).

- **Single-Gen2 plans (WS2025):** the one SKU *is* the plan-id SKU → `skuId = <planSKU>` (no `-g2`).
- **Dual plans (keep Gen1 + add Gen2):** Gen1 `skuId = <planSKU>` (satisfies rule 2) + Gen2
  `skuId = <planSKU>-g2`.

## Immutability

A published image version / imageType SKU **can't be modified once published** (API and Portal).
While still a **draft** it *can* be modified via the API (but not via the Portal). To change a
published image, **append a new version number** (old versions may be deprecated via
`lifecycleState`) rather than mutating. In diffs, a stripped `id` (server-owned; writes identify by
product+plan) and `$schema` position changes are expected/benign.

## Pipeline automation (Publish Preview Images)

`Add-MarketplaceGen2Image.ps1` runs as a job at the **start of the `PublishPreviewImages` stage** of
`Azure Publish Images.yaml`, ahead of the manual "publish to preview" validation. It automates what
was previously a manual "add the new image" step: it adds each newly-built (and tested) gallery image
to the offer's **draft**, leaving the human to do the actual publish-to-preview.

- **Plan list is derived from the artefacts**, not hard-coded. The build pipeline drops one
  `<plan>/<plan>.txt` per built plan (holding the gallery ImageUrl — same layout
  `azure_set_gate_variable.ps1` reads). The job enumerates `_BuildImageReleaseArtefacts/*`; a folder
  without its `.txt` is skipped, and **zero artefacts is fatal** (the run's whole purpose is to
  publish ≥1 image). `-PlanExternalId` is an optional filter.
- **Everything derives from the ImageUrl**: `resourceId` (verbatim), version (after `/versions/`),
  and the image definition (after `/images/`); a `-g2` suffix ⇒ `x64Gen2` and the plan externalId is
  the def minus `-g2`.
- **Fixed values are hard-coded** (not parameters): product durable id
  `product/9c420de5-…`, gallery tenantId `17e16064-…`. Only the Partner Center auth
  (`PCTenantId` / `PCClientId` / `PCClientSecret` — "PC" = Partner Center) is passed in as pipeline
  variables.
- **Idempotent + append-only**: GETs the plan's current tech config, skips if that image version is
  already present, otherwise **appends** the new version and ensures a Gen2 SKU exists (per the SKU
  rules above). Never mutates an existing image (see Immutability).
- **Draft vs live**: a durable-id GET returns the **draft**; if a plan is live with no pending draft
  that 404s, so it falls back to the **live** config via `resource-tree?targetType=live` and the
  submit then seeds a fresh draft. It logs `base config from: draft|live` per plan.

Related Azure MSI context: [azure-sql-login.md](azure-sql-login.md).
